//
//  SetVariable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-13.
//  Copyright © 2015–2017 Károly Lőrentey.
//

open class SetVariable<Element: Hashable>: _BaseUpdatableSet<Element>, ExpressibleByArrayLiteral {
    public typealias Value = Set<Element>
    public typealias Change = SetChange<Element>

    fileprivate var _value: Value

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

    public required convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }

    final public override var isBuffered: Bool {
        return true
    }

    public var isEmpty: Bool {
        return _value.isEmpty
    }

    final public override var count: Int {
        return _value.count
    }

    final public override var value: Value {
        get {
            return _value
        }
        set {
            beginTransaction()
            let v = _value
            _value = newValue
            sendChange(SetChange(removed: v, inserted: newValue))
            endTransaction()
        }
    }

    final public override func contains(_ member: Element) -> Bool {
        return _value.contains(member)
    }

    final public override func isSubset(of other: Set<Element>) -> Bool {
        return _value.isSubset(of: other)
    }

    final public override func isSuperset(of other: Set<Element>) -> Bool {
        return _value.isSuperset(of: other)
    }

    override func rawApply(_ change: SetChange<Element>) {
        _value.apply(change)
    }

    final public override func remove(_ member: Element) {
        guard _value.contains(member) else { return }
        if isConnected {
            beginTransaction()
            _value.remove(member)
            sendChange(SetChange(removed: [member], inserted: []))
            endTransaction()
        }
        else {
            _value.remove(member)
        }
    }

    final public override func insert(_ member: Element) {
        guard !_value.contains(member) else { return }
        if isConnected {
            beginTransaction()
            _value.insert(member)
            sendChange(SetChange(removed: [], inserted: [member]))
            endTransaction()
        }
        else {
            _value.insert(member)
        }
    }

    final public override func removeAll() {
        guard !isEmpty else { return }
        let value = self._value
        if isConnected {
            beginTransaction()
            _value.removeAll()
            sendChange(SetChange(removed: value, inserted: []))
            endTransaction()
        }
        else {
            _value.removeAll()
        }
    }


    final public override func formUnion(_ other: Set<Element>) {
        if isConnected {
            beginTransaction()
            let difference = other.subtracting(_value)
            _value.formUnion(difference)
            sendChange(SetChange(removed: [], inserted: difference))
            endTransaction()
        }
        else {
            _value.formUnion(other)
        }
    }

    final public override func formIntersection(_ other: Set<Element>) {
        if isConnected {
            beginTransaction()
            let difference = _value.subtracting(other)
            _value.subtract(difference)
            sendChange(SetChange(removed: difference, inserted: []))
            endTransaction()
        }
        else {
            _value.formIntersection(other)
        }
    }

    final public override func formSymmetricDifference(_ other: Set<Element>) {
        if isConnected {
            beginTransaction()
            let intersection = _value.intersection(other)
            let additions = other.subtracting(self.value)
            _value.formSymmetricDifference(other)
            sendChange(SetChange(removed: intersection, inserted: additions))
            endTransaction()
        }
        else {
            _value.formSymmetricDifference(other)
        }
    }

    final public override func subtract(_ other: Set<Element>) {
        if isConnected {
            beginTransaction()
            let intersection = _value.intersection(other)
            _value.subtract(other)
            sendChange(SetChange(removed: intersection, inserted: []))
            endTransaction()
        }
        else {
            _value.subtract(other)
        }
    }
}

extension SetVariable {
    public func update(with member: Element) -> Element? {
        beginTransaction()
        let old = _value.update(with: member)
        if isConnected {
            if let old = old {
                sendChange(SetChange(removed: [old], inserted: [member]))
            }
            else {
                sendChange(SetChange(removed: [], inserted: [member]))
            }
        }
        endTransaction()
        return old
    }
}
