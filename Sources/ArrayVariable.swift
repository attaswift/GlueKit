//
//  ArrayVariable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-08.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

//MARK: ArrayVariable

public final class ArrayVariable<Element>: UpdatableArrayBase<Element> {
    public typealias Index = Int
    public typealias IndexDistance = Int
    public typealias Indices = CountableRange<Int>
    public typealias Base = Array<Element>
    public typealias Value = Array<Element>
    public typealias Change = ArrayChange<Element>
    public typealias Iterator = Array<Element>.Iterator
    public typealias SubSequence = Array<Element>.SubSequence

    fileprivate var _value: [Element]
    fileprivate var _apply: ((Change) -> Void)? = nil
    fileprivate var _signal = ChangeSignal<Change>()

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

    public override func batchUpdate(_ body: () -> Void) {
        _signal.willChange()
        body()
        _signal.didNotChange()
    }

    public override func apply(_ change: ArrayChange<Iterator.Element>) {
        if change.isEmpty { return }
        _signal.willChange()
        _value.apply(change)
        _signal.didChange(change)
    }

    public override var value: Base {
        get {
            return _value
        }
        set {
            if !_signal.isActive {
                _value = newValue
            }
            else {
                let old = _value
                _signal.willChange()
                _value = newValue
                _signal.didChange(ArrayChange(initialCount: old.count, modification: .replaceSlice(old, at: 0, with: newValue)))
            }
        }
    }

    public override var count: Int {
        return _value.count
    }

    /// A source that reports all future changes of this variable.
    public override var changeEvents: Source<ChangeEvent<Change>> {
        return _signal.source(holding: self)
    }

    public override var isBuffered: Bool {
        return true
    }

    public override subscript(index: Int) -> Element {
        get {
            return _value[index]
        }
        set {
            if !_signal.isActive {
                _value[index] = newValue
            }
            else {
                let old = _value[index]
                _signal.willChange()
                _value[index] = newValue
                _signal.didChange(ArrayChange(initialCount: _value.count, modification: .replace(old, at: index, with: newValue)))
            }
        }
    }

    public override subscript(bounds: Range<Int>) -> SubSequence {
        get {
            return value[bounds]
        }
        set {
            if !_signal.isActive {
                _value[bounds] = newValue
            }
            if _signal.isConnected {
                let oldCount = _value.count
                let old = Array(_value[bounds])
                _value[bounds] = newValue
                _signal.didChange(ArrayChange(initialCount: oldCount, modification: .replaceSlice(old, at: bounds.lowerBound, with: Array(newValue))))
            }
        }
    }
}

extension ArrayVariable: ExpressibleByArrayLiteral {
    public convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}
