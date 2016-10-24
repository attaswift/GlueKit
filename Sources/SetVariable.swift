//
//  SetVariable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-13.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

public final class SetVariable<Element: Hashable>: _AsbtractUpdatableSet<Element> {
    public typealias Value = Set<Element>
    public typealias Base = Set<Element>
    public typealias Change = SetChange<Element>

    fileprivate var _value: Base
    fileprivate var _state = TransactionState<Change>()

    public override init() {
        _value = []
    }

    public init(_ elements: [Element]) {
        _value = Set(elements)
    }

    public init(_ elements: Set<Element>) {
        _value = elements
    }

    public init<S: Sequence>(_ elements: S) where S.Iterator.Element == Element {
        _value = Set(elements)
    }

    public init(elements: Element...) {
        _value = Set(elements)
    }

    public override var isBuffered: Bool {
        return true
    }

    public var isEmpty: Bool {
        return _value.isEmpty
    }

    public override var count: Int {
        return _value.count
    }

    public override var value: Value {
        get {
            return _value
        }
        set {
            _state.begin()
            let v = _value
            _value = newValue
            _state.send(SetChange(removed: v, inserted: newValue))
            _state.end()
        }
    }

    public override func contains(_ member: Element) -> Bool {
        return _value.contains(member)
    }

    public override func isSubset(of other: Set<Element>) -> Bool {
        return _value.isSubset(of: other)
    }

    public override func isSuperset(of other: Set<Element>) -> Bool {
        return _value.isSuperset(of: other)
    }

    public override var updates: SetUpdateSource<Element> {
        return _state.source(retaining: self)
    }

    public override func withTransaction<Result>(_ body: () -> Result) -> Result {
        _state.begin()
        defer { _state.end() }
        return body()
    }
    
    public override func apply(_ change: SetChange<Element>) {
        guard !change.isEmpty else { return }
        _state.begin()
        _value.apply(change)
        _state.send(change)
        _state.end()
    }

    public override func remove(_ member: Element) {
        guard _value.contains(member) else { return }
        _state.begin()
        _value.remove(member)
        _state.sendIfConnected(SetChange(removed: [member], inserted: []))
        _state.end()
    }

    public override func insert(_ member: Element) {
        guard !_value.contains(member) else { return }
        _state.begin()
        _value.insert(member)
        _state.sendIfConnected(SetChange(removed: [], inserted: [member]))
        _state.end()
    }

    public override func removeAll() {
        guard !isEmpty else { return }
        let value = self._value
        _state.begin()
        _value.removeAll()
        _state.sendIfConnected(SetChange(removed: value, inserted: []))
        _state.end()
    }


    public override func formUnion(_ other: Set<Element>) {
        if _state.isConnected {
            _state.begin()
            let difference = other.subtracting(_value)
            _value.formUnion(difference)
            _state.send(SetChange(removed: [], inserted: difference))
            _state.end()
        }
        else {
            _value.formUnion(other)
        }
    }

    public override func formIntersection(_ other: Set<Element>) {
        if _state.isConnected {
            _state.begin()
            let difference = _value.subtracting(other)
            _value.subtract(difference)
            _state.send(SetChange(removed: difference, inserted: []))
            _state.end()
        }
        else {
            _value.formIntersection(other)
        }
    }

    public override func formSymmetricDifference(_ other: Set<Element>) {
        if _state.isConnected {
            _state.begin()
            let intersection = _value.intersection(other)
            let additions = other.subtracting(self.value)
            _value.formSymmetricDifference(other)
            _state.send(SetChange(removed: intersection, inserted: additions))
            _state.end()
        }
        else {
            _value.formSymmetricDifference(other)
        }
    }

    public override func subtract(_ other: Set<Element>) {
        if _state.isConnected {
            _state.begin()
            let intersection = _value.intersection(other)
            _value.subtract(other)
            _state.send(SetChange(removed: intersection, inserted: []))
            _state.end()
        }
        else {
            _value.subtract(other)
        }
    }
}

extension SetVariable: ExpressibleByArrayLiteral {
    public convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension SetVariable {
    public func update(with member: Element) -> Element? {
        _state.begin()
        let old = _value.update(with: member)
        if let old = old {
            _state.sendIfConnected(SetChange(removed: [old], inserted: [member]))
        }
        else {
            _state.sendIfConnected(SetChange(removed: [], inserted: [member]))
        }
        _state.end()
        return old
    }
}

extension UpdatableSetType {
    public func modify(_ block: (SetVariable<Element>)->Void) {
        let set = SetVariable<Self.Element>(self.value)
        var change = SetChange<Self.Element>()
        let connection = set.changes.connect { c in change.merge(with: c) }
        block(set)
        connection.disconnect()
        self.apply(change)
    }
}
