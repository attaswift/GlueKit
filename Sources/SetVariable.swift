//
//  SetVariable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-13.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

public final class SetVariable<Element: Hashable>: UpdatableSetType {
    public typealias Value = Set<Element>
    public typealias Base = Set<Element>
    public typealias Change = SetChange<Element>

    public typealias Iterator = Base.Iterator
    public typealias Index = Base.Index
    public typealias IndexDistance = Base.IndexDistance
    public typealias Indices = Base.Indices
    public typealias SubSequence = Base.SubSequence

    private var _value: Base
    private var _changeSignal = LazySignal<Change>()
    private var _valueSignal = LazySignal<Value>()

    public init() {
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

    public var value: Value {
        get {
            return _value
        }
        set {
            let v = _value
            _value = newValue
            _changeSignal.sendIfConnected(SetChange(removed: v, inserted: newValue))
            _valueSignal.sendIfConnected(_value)
        }
    }

    public var count: Int {
        return _value.count
    }

    public func contains(_ member: Element) -> Bool {
        return _value.contains(member)
    }

    public func apply(_ change: SetChange<Element>) {
        guard !change.isEmpty else { return }
        _value.apply(change)
        _changeSignal.sendIfConnected(change)
        _valueSignal.sendIfConnected(_value)
    }

    public var futureChanges: Source<SetChange<Element>> {
        return _changeSignal.source
    }

    public var observable: Observable<Set<Element>> {
        return Observable(getter: { self._value }, futureValues: { self._valueSignal.source })
    }

    public var observableSet: ObservableSet<Element> {
        return ObservableSet(value: { self._value }, futureChanges: { self._changeSignal.source })
    }

    public static func ==(a: SetVariable, b: SetVariable) -> Bool {
        return a.value == b.value
    }
}

extension SetVariable: ExpressibleByArrayLiteral {
    public convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension SetVariable {
    public func insert(_ member: Element) {
        guard !_value.contains(member) else { return }
        _value.insert(member)
        _changeSignal.sendIfConnected(SetChange(removed: [], inserted: [member]))
        _valueSignal.sendIfConnected(_value)
    }

    public func remove(_ member: Element) {
        guard _value.contains(member) else { return }
        _value.remove(member)
        _changeSignal.sendIfConnected(SetChange(removed: [member], inserted: []))
        _valueSignal.sendIfConnected(value)
    }

    public func update(with member: Element) -> Element? {
        let old = _value.update(with: member)
        if let old = old {
            _changeSignal.sendIfConnected(SetChange(removed: [old], inserted: [member]))
        }
        else {
            _changeSignal.sendIfConnected(SetChange(removed: [], inserted: [member]))
        }
        _valueSignal.sendIfConnected(_value)
        return old
    }

    public func formUnion(_ other: Set<Element>) {
        if _changeSignal.isConnected {
            let difference = other.subtracting(_value)
            _value.formUnion(difference)
            _changeSignal.sendIfConnected(SetChange(removed: [], inserted: difference))
        }
        else {
            _value.formUnion(other)
        }
        _valueSignal.sendIfConnected(_value)
    }

    public func formIntersection(_ other: Set<Element>) {
        if _changeSignal.isConnected {
            let difference = _value.subtracting(other)
            _value.subtract(difference)
            _changeSignal.sendIfConnected(SetChange(removed: difference, inserted: []))
        }
        else {
            _value.formIntersection(other)
        }
        _valueSignal.sendIfConnected(_value)
    }

    public func formSymmetricDifference(_ other: Set<Element>) {
        if _changeSignal.isConnected {
            let intersection = _value.intersection(other)
            let additions = other.subtracting(self)
            _value.formSymmetricDifference(other)
            _changeSignal.sendIfConnected(SetChange(removed: intersection, inserted: additions))
        }
        else {
            _value.formSymmetricDifference(other)
        }
        _valueSignal.sendIfConnected(_value)
    }

    public func subtract(_ other: Set<Element>) {
        if _changeSignal.isConnected {
            let intersection = _value.intersection(other)
            _value.subtract(other)
            _changeSignal.sendIfConnected(SetChange(removed: intersection, inserted: []))
        }
        else {
            _value.subtract(other)
        }
        _valueSignal.sendIfConnected(_value)
    }
}
