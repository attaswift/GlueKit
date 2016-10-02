//
//  ArrayVariable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-08.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

//MARK: ArrayVariable

public final class ArrayVariable<E>: UpdatableArrayType {
    public typealias Element = E
    public typealias Index = Int
    public typealias IndexDistance = Int
    public typealias Indices = CountableRange<Int>
    public typealias Base = Array<Element>
    public typealias Change = ArrayChange<Element>
    public typealias Iterator = Array<Element>.Iterator
    public typealias SubSequence = Array<Element>.SubSequence

    fileprivate var _value: [Element]
    fileprivate var _changeSignal = LazySignal<Change>()
    fileprivate var _valueSignal = LazySignal<[Element]>()

    public init() {
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

    public var value: Base {
        get {
            return _value
        }
        set {
            let c = _value.count
            let old = _value
            _value = newValue
            _changeSignal.sendIfConnected(ArrayChange(initialCount: c, modification: .replaceSlice(old, at: 0, with: newValue)))
            _valueSignal.sendIfConnected(newValue)
        }
    }

    public var count: Int {
        return _value.count
    }

    /// A source that reports all future changes of this variable.
    public var changes: Source<ArrayChange<Element>> {
        return _changeSignal.source
    }

    public var observable: Observable<[Element]> {
        return Observable(getter: { self.value }, futureValues: { self._valueSignal.source })
    }

    public var isBuffered: Bool {
        return true
    }

    public subscript(index: Int) -> Element {
        get {
            return _value[index]
        }
        set {
            if _changeSignal.isConnected {
                let old = _value[index]
                _value[index] = newValue
                _changeSignal.send(ArrayChange(initialCount: _value.count, modification: .replace(old, at: index, with: newValue)))
            }
            else {
                _value[index] = newValue
            }
            _valueSignal.sendIfConnected(_value)
        }
    }

    public subscript(bounds: Range<Int>) -> SubSequence {
        get {
            return value[bounds]
        }
        set {
            if _changeSignal.isConnected {
                let oldCount = _value.count
                let old = Array(_value[bounds])
                _value[bounds] = newValue
                _changeSignal.send(ArrayChange(initialCount: oldCount, modification: .replaceSlice(old, at: bounds.lowerBound, with: Array(newValue))))
            }
            else {
                _value[bounds] = newValue
            }
            _valueSignal.sendIfConnected(_value)
        }
    }

    public func apply(_ change: ArrayChange<Iterator.Element>) {
        guard !change.isEmpty else { return }
        _value.apply(change)
        _changeSignal.sendIfConnected(change)
        _valueSignal.sendIfConnected(value)
    }

    public var updatable: Updatable<[Element]> {
        return Updatable(getter: { self.value }, setter: { self.value = $0 }, futureValues: { self._valueSignal.source })
    }
}

extension ArrayVariable: ExpressibleByArrayLiteral {
    public convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}
