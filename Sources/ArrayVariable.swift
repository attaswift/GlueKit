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
    public typealias Value = Array<Element>
    public typealias Change = ArrayChange<Element>

    fileprivate var _value: [Element]
    fileprivate var _apply: ((Change) -> Void)? = nil
    fileprivate var _state = TransactionState<Change>()

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
        _state.begin()
        body()
        _state.end()
    }

    public override func apply(_ change: ArrayChange<Element>) {
        if change.isEmpty { return }
        if _state.isConnected {
            _state.begin()
            _value.apply(change)
            _state.send(change)
            _state.end()
        }
        else {
            _value.apply(change)
        }
    }

    public override var value: [Element] {
        get {
            return _value
        }
        set {
            if _state.isConnected {
                let old = _value
                _state.begin()
                _value = newValue
                _state.send(ArrayChange(initialCount: old.count, modification: .replaceSlice(old, at: 0, with: newValue)))
                _state.end()
            }
            else {
                _value = newValue
            }
        }
    }

    public override var count: Int {
        return _value.count
    }

    /// A source that reports all future changes of this variable.
    public override var updates: Source<Update<Change>> {
        return _state.source(retaining: self)
    }

    public override var isBuffered: Bool {
        return true
    }

    public override subscript(index: Int) -> Element {
        get {
            return _value[index]
        }
        set {
            if _state.isConnected {
                let old = _value[index]
                _state.begin()
                _value[index] = newValue
                _state.send(ArrayChange(initialCount: _value.count, modification: .replace(old, at: index, with: newValue)))
                _state.end()
            }
            else {
                _value[index] = newValue
            }
        }
    }

    public override subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        get {
            return value[bounds]
        }
        set {
            if _state.isConnected {
                let oldCount = _value.count
                let old = Array(_value[bounds])
                _state.begin()
                _value[bounds] = newValue
                _state.send(ArrayChange(initialCount: oldCount,
                                        modification: .replaceSlice(old, at: bounds.lowerBound, with: Array(newValue))))
                _state.end()
            }
            else {
                _value[bounds] = newValue
            }
        }
    }
}

extension ArrayVariable: ExpressibleByArrayLiteral {
    public convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}
