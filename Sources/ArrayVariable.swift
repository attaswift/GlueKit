//
//  ArrayVariable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-08.
//  Copyright © 2015–2017 Károly Lőrentey.
//

open class ArrayVariable<Element>: _BaseUpdatableArray<Element>, ExpressibleByArrayLiteral {
    public typealias Value = Array<Element>
    public typealias Change = ArrayChange<Element>

    fileprivate var _value: [Element]

    public override init() {
        _value = []
    }
    public init(_ elements: [Element]) {
        _value = elements
    }
    public init<S: Sequence>(_ elements: S) where S.Iterator.Element == Element {
        _value = Array(elements)
    }
    public init(elements: Element...) {
        _value = elements
    }
    public required convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }

    override func rawApply(_ change: ArrayChange<Element>) {
        _value.apply(change)
    }

    final public override var value: [Element] {
        get {
            return _value
        }
        set {
            if isConnected {
                let old = _value
                beginTransaction()
                _value = newValue
                sendChange(ArrayChange(from: old, to: newValue))
                endTransaction()
            }
            else {
                _value = newValue
            }
        }
    }

    final public override var count: Int {
        return _value.count
    }

    final public override var isBuffered: Bool {
        return true
    }

    final public override subscript(index: Int) -> Element {
        get {
            return _value[index]
        }
        set {
            if isConnected {
                let old = _value[index]
                beginTransaction()
                _value[index] = newValue
                sendChange(ArrayChange(initialCount: _value.count, modification: .replace(old, at: index, with: newValue)))
                endTransaction()
            }
            else {
                _value[index] = newValue
            }
        }
    }

    final public override subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        get {
            return value[bounds]
        }
        set {
            if isConnected {
                let oldCount = _value.count
                let old = Array(_value[bounds])
                beginTransaction()
                _value[bounds] = newValue
                sendChange(ArrayChange(initialCount: oldCount,
                                        modification: .replaceSlice(old, at: bounds.lowerBound, with: Array(newValue))))
                endTransaction()
            }
            else {
                _value[bounds] = newValue
            }
        }
    }
}

