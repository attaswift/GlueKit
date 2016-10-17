//
//  SetSortingByMappingToObservableComparable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import BTree

extension ObservableSetType where Element: AnyObject {
    /// Given a transformation into an observable of a comparable type, return an observable array
    /// containing transformed versions of elements in this set, in increasing order.
    public func sorted<O: ObservableValueType>(by transform: @escaping (Element) -> O) -> ObservableArray<O.Value> where O.Value: Comparable {
        return SetSortingByMappingToObservableComparable(base: self, transform: transform).observableArray
    }
}

private class SetSortingByMappingToObservableComparable<S: ObservableSetType, R: ObservableValueType>: ObservableArrayBase<R.Value>
where S.Element: AnyObject, R.Value: Comparable {
    typealias Element = R.Value
    typealias Change = ArrayChange<Element>

    private let base: S
    private let transform: (S.Element) -> R

    private var state: Map<Element, Int> = [:]
    private var signal = OwningSignal<Change>()
    private var baseConnection: Connection? = nil
    private var connections: Dictionary<S.Element, Connection> = [:]

    init(base: S, transform: @escaping (S.Element) -> R) {
        self.base = base
        self.transform = transform
        super.init()

        for element in base.value {
            _ = self._insert(newElement(element))
        }
        baseConnection = base.changes.connect { [unowned self] change in self.apply(change) }
    }

    deinit {
        baseConnection?.disconnect()
        connections.forEach { (_, connection) in connection.disconnect() }
    }

    private func newElement(_ element: S.Element) -> Element {
        let transformed = transform(element)
        connections[element] = transformed.changes.connect { [unowned self] in self.apply($0) }
        return transformed.value
    }

    private func removeElement(_ element: S.Element) {
        let connection = connections.removeValue(forKey: element)
        connection!.disconnect()
    }

    private func _insert(_ key: Element) -> Bool {
        if let count = state[key] {
            state[key] = count + 1
            return false
        }
        state[key] = 1
        return true
    }

    private func insert(_ key: Element) -> ArrayModification<Element>? {
        return _insert(key) ? .insert(key, at: state.offset(of: key)!) : nil
    }

    private func remove(_ key: Element) -> ArrayModification<Element>? {
        guard let count = self.state[key] else {
            fatalError("Inconsistent change: element removed is not in sorted set")
        }
        if count > 1 {
            state[key] = count - 1
            return nil
        }
        let oldOffset = state.offset(of: key)!
        state.removeValue(forKey: key)
        return .remove(key, at: oldOffset)
    }

    private func apply(_ change: SetChange<S.Element>) {
        var arrayChange = ArrayChange<Element>(initialCount: state.count)
        for element in change.removed {
            let key = transform(element).value
            removeElement(element)
            if let mod = self.remove(key) {
                arrayChange.add(mod)
            }
        }
        for element in change.inserted {
            let key = newElement(element)
            if let mod = self.insert(key) {
                arrayChange.add(mod)
            }
        }
        if !arrayChange.isEmpty {
            signal.send(arrayChange)
        }
    }

    private func apply(_ change: ValueChange<Element>) {
        var arrayChange = ArrayChange<Element>(initialCount: self.state.count)
        if change.old == change.new { return }
        if let mod = remove(change.old) {
            arrayChange.add(mod)
        }
        if let mod = insert(change.new) {
            arrayChange.add(mod)
        }
        if !arrayChange.isEmpty {
            self.signal.send(arrayChange)
        }
    }

    override var isBuffered: Bool { return false }
    override subscript(index: Int) -> Element { return state.element(atOffset: index).0 }
    override subscript(bounds: Range<Int>) -> ArraySlice<Element> { return ArraySlice(state.submap(withOffsets: bounds).lazy.map { $0.0 }) }
    override var value: Array<Element> { return Array(state.lazy.map { $0.0 }) }
    override var count: Int { return state.count }
    override var changes: Source<ArrayChange<Element>> { return signal.with(retained: self).source }
}

