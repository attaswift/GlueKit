//
//  SetFolding.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableSetType {
    /// Returns an observable whose value is always equal to `self.value.reduce(initial, add)`.
    ///
    /// - Parameter initial: The accumulation starts with this initial value.
    /// - Parameter add: A closure that adds an element of the set into an accumulated value.
    /// - Parameter remove: A closure that cancels the effect of an earlier `add`.
    /// - Returns: An observable value for the reduction of this set.
    ///
    /// - Note: Elements are added and removed in no particular order.
    ///    (I.e., the underlying binary operation over `Result` must form an abelian group.)
    ///
    /// - SeeAlso: `sum()` which returns a reduction using addition.
    public func reduce<Result>(_ initial: Result, add: @escaping (Result, Element) -> Result, remove: @escaping (Result, Element) -> Result) -> Observable<Result> {
        return SetFoldingByTwoWayFunction<Self, Result>(base: self, initial: initial, add: add, remove: remove).observable
    }
}

extension ObservableSetType where Element: IntegerArithmetic & ExpressibleByIntegerLiteral {
    /// Return the (observable) sum of the elements contained in this set.
    public func sum() -> Observable<Element> {
        return reduce(0, add: +, remove: -)
    }
}

private class SetFoldingByTwoWayFunction<Base: ObservableSetType, Value>: ObservableBoxBase<Value> {
    private var _value: Value
    private var _signal = OwningSignal<SimpleChange<Value>>()

    let add: (Value, Base.Element) -> Value
    let remove: (Value, Base.Element) -> Value
    var connection: Connection? = nil

    init(base: Base, initial: Value, add: @escaping (Value, Base.Element) -> Value, remove: @escaping (Value, Base.Element) -> Value) {
        self._value = base.value.reduce(initial, add)
        self.add = add
        self.remove = remove
        super.init()

        connection = base.changes.connect { [unowned self] change in self.apply(change) }
    }

    deinit {
        connection!.disconnect()
    }

    private func apply(_ change: SetChange<Base.Element>) {
        let old = _value
        for old in change.removed { _value = remove(_value, old) }
        for new in change.inserted { _value = add(_value, new) }
        _signal.send(SimpleChange(from: old, to: _value))
    }

    override var value: Value { return _value }
    override var changes: Source<SimpleChange<Value>> { return _signal.with(retained: self).source }
}
