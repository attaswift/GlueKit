//
//  SetSorting.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-15.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import BTree

extension ObservableSetType {
    /// Given a transformation into a comparable type, return an observable array containing transformed
    /// versions of elements in this set, in increasing order.
    public func sorted<Result: Comparable>(by transform: @escaping (Element) -> Result) -> ObservableArray<Result> {
        return SetSortingUsingComparableMapping(base: self, transform: transform).observableArray
    }
}

extension ObservableSetType where Element: Comparable {
    /// Return an observable array containing the members of this set, in increasing order.
    public func sorted() -> ObservableArray<Element> {
        return self.sorted { $0 }
    }
}

class SetSortingUsingComparableMapping<S: ObservableSetType, R: Comparable>: ObservableArrayType {
    typealias Element = R
    typealias Change = ArrayChange<R>

    private let base: S
    private let transform: (S.Element) -> R

    private var state: Map<R, Int> = [:]
    private var signal = OwningSignal<Change>()
    private var baseConnection: Connection? = nil

    init(base: S, transform: @escaping (S.Element) -> R) {
        self.base = base
        self.transform = transform

        for element in base.value {
            let transformed = transform(element)
            state[transformed] = (state[transformed] ?? 0) + 1
        }
        baseConnection = base.changes.connect { [unowned self] change in self.apply(change) }
    }

    deinit {
        baseConnection?.disconnect()
    }

    private func apply(_ change: SetChange<S.Element>) {
        var arrayChange: ArrayChange<Element>? = signal.isConnected ? ArrayChange(initialCount: state.count) : nil
        for element in change.removed {
            let transformed = transform(element)
            guard let index = state.index(forKey: transformed) else { fatalError("Removed element '\(transformed)' not found in sorted set") }
            let count = state[index].1
            if count == 1 {
                let offset = state.offset(of: index)
                let old = state.remove(at: index)
                arrayChange?.add(.remove(old.key, at: offset))
            }
            else {
                state[transformed] = count - 1
            }
        }
        for element in change.inserted {
            let transformed = transform(element)
            if let count = state[transformed] {
                state[transformed] = count + 1
            }
            else {
                state[transformed] = 1
                if arrayChange != nil {
                    let offset = state.offset(of: transformed)!
                    arrayChange!.add(.insert(transformed, at: offset))
                }
            }
        }
        if let a = arrayChange, !a.isEmpty {
            signal.send(a)
        }
    }

    var isBuffered: Bool { return false }
    var count: Int { return state.count }
    var value: Array<Element> { return Array(state.lazy.map { $0.0 }) }
    subscript(index: Int) -> Element { return state.element(atOffset: index).0 }
    subscript(bounds: Range<Int>) -> ArraySlice<Element> { return ArraySlice(state.submap(withOffsets: bounds).lazy.map { $0.0 }) }

    var changes: Source<ArrayChange<R>> { return signal.with(retained: self).source }
}

//MARK: -

extension ObservableSetType {
    public func sorted(by areInIncreasingOrder: @escaping (Element, Element) -> Bool) -> ObservableArray<Element> {
        let comparator = Comparator(areInIncreasingOrder)
        return self
            .sorted(by: { [unowned(unsafe) comparator] in ComparableWrapper($0, comparator) })
            .map { [comparator] in _ = comparator; return $0.element }
    }

    public func sorted<Comparator: ObservableValueType>(by comparator: Comparator) -> ObservableArray<Element> where Comparator.Value == (Element, Element) -> Bool {
        let reference = ObservableArrayReference<Element>()
        let connection = comparator.values.connect { comparatorValue in
            reference.retarget(to: self.sorted(by: comparatorValue))
        }
        return reference.observableArray.holding(connection)
    }
}

private final class Comparator<Element: Equatable> {
    let comparator: (Element, Element) -> Bool

    init(_ comparator: @escaping (Element, Element) -> Bool) {
        self.comparator = comparator
    }
    func compare(_ a: Element, _ b: Element) -> Bool {
        return comparator(a, b)
    }
}

private struct ComparableWrapper<Element: Equatable>: Comparable {
    unowned(unsafe) let comparator: Comparator<Element>
    let element: Element

    init(_ element: Element, _ comparator: Comparator<Element>) {
        self.comparator = comparator
        self.element = element
    }
    static func ==(a: ComparableWrapper<Element>, b: ComparableWrapper<Element>) -> Bool {
        return a.element == b.element
    }
    static func <(a: ComparableWrapper<Element>, b: ComparableWrapper<Element>) -> Bool {
        return a.comparator.compare(a.element, b.element)
    }
}

//MARK: -

extension ObservableSetType where Element: AnyObject {
    /// Given a transformation into an observable of a comparable type, return an observable array
    /// containing transformed versions of elements in this set, in increasing order.
    public func sorted<O: ObservableValueType>(by transform: @escaping (Element) -> O) -> ObservableArray<O.Value> where O.Value: Comparable {
        return SetSortingUsingObservableComparableMapping(base: self, transform: transform).observableArray
    }
}

class SetSortingUsingObservableComparableMapping<S: ObservableSetType, R: ObservableValueType>: ObservableArrayType
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

    private func apply(_ change: SimpleChange<Element>) {
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

    var isBuffered: Bool { return false }
    var count: Int { return state.count }
    var value: Array<Element> { return Array(state.lazy.map { $0.0 }) }
    subscript(index: Int) -> Element { return state.element(atOffset: index).0 }
    subscript(bounds: Range<Int>) -> ArraySlice<Element> { return ArraySlice(state.submap(withOffsets: bounds).lazy.map { $0.0 }) }

    var changes: Source<ArrayChange<Element>> { return signal.with(retained: self).source }
}

