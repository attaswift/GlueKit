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
        return SetSortingByMappingToObservableComparable(parent: self, transform: transform).observableArray
    }
}

private class SetSortingByMappingToObservableComparable<Parent: ObservableSetType, Field: ObservableValueType>: ObservableArrayBase<Field.Value>
where Parent.Element: AnyObject, Field.Value: Comparable {
    typealias Element = Field.Value
    typealias Change = ArrayChange<Element>

    private let parent: Parent
    private let transform: (Parent.Element) -> Field

    private var contents: Map<Element, Int> = [:]
    private var state = TransactionState<Change>()
    private var baseConnection: Connection? = nil
    private var connections: Dictionary<Parent.Element, Connection> = [:]

    init(parent: Parent, transform: @escaping (Parent.Element) -> Field) {
        self.parent = parent
        self.transform = transform
        super.init()

        for element in parent.value {
            _ = self._insert(newElement(element))
        }
        baseConnection = parent.updates.connect { [unowned self] in self.apply($0) }
    }

    deinit {
        baseConnection?.disconnect()
        connections.forEach { (_, connection) in connection.disconnect() }
    }

    private func newElement(_ element: Parent.Element) -> Element {
        let transformed = transform(element)
        connections[element] = transformed.updates.connect { [unowned self] in self.apply($0) }
        return transformed.value
    }

    private func removeElement(_ element: Parent.Element) {
        let connection = connections.removeValue(forKey: element)
        connection!.disconnect()
    }

    private func _insert(_ key: Element) -> Bool {
        if let count = contents[key] {
            contents[key] = count + 1
            return false
        }
        contents[key] = 1
        return true
    }

    private func insert(_ key: Element) -> ArrayModification<Element>? {
        return _insert(key) ? .insert(key, at: contents.offset(of: key)!) : nil
    }

    private func remove(_ key: Element) -> ArrayModification<Element>? {
        guard let count = self.contents[key] else {
            fatalError("Inconsistent change: element removed is not in sorted set")
        }
        if count > 1 {
            contents[key] = count - 1
            return nil
        }
        let oldOffset = contents.offset(of: key)!
        contents.removeValue(forKey: key)
        return .remove(key, at: oldOffset)
    }

    private func apply(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            state.begin()
        case .change(let change):
            var arrayChange = ArrayChange<Element>(initialCount: contents.count)
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
                state.send(arrayChange)
            }
        case .endTransaction:
            state.end()
        }
    }

    private func apply(_ update: ValueUpdate<Element>) {
        switch update {
        case .beginTransaction:
            state.begin()
        case .change(let change):
            var arrayChange = ArrayChange<Element>(initialCount: self.contents.count)
            if change.old == change.new { return }
            if let mod = remove(change.old) {
                arrayChange.add(mod)
            }
            if let mod = insert(change.new) {
                arrayChange.add(mod)
            }
            if !arrayChange.isEmpty {
                state.send(arrayChange)
            }
        case .endTransaction:
            state.end()
        }
    }

    override var isBuffered: Bool { return false }
    override subscript(index: Int) -> Element { return contents.element(atOffset: index).0 }
    override subscript(bounds: Range<Int>) -> ArraySlice<Element> { return ArraySlice(contents.submap(withOffsets: bounds).lazy.map { $0.0 }) }
    override var value: Array<Element> { return Array(contents.lazy.map { $0.0 }) }
    override var count: Int { return contents.count }
    override var updates: ArrayUpdateSource<Element> { return state.source(retaining: self) }
}

