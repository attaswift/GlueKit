//
//  ArrayFolding.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableArrayType {
    /// Returns an observable whose value is always equal to `self.value.reduce(initial, add)`.
    ///
    /// - Parameter initial: The accumulation starts with this initial value.
    /// - Parameter add: A closure that adds an element of the array into an accumulated value.
    /// - Parameter remove: A closure that cancels the effect of an earlier `add`.
    /// - Returns: An observable value for the reduction of this array.
    ///
    /// - Note: Elements are added and removed in no particular order. 
    ///    (I.e., the underlying binary operation over `Result` must form an abelian group.)
    ///
    /// - SeeAlso: `sum()` which returns a reduction using addition.
    public func reduce<Result>(_ initial: Result, add: @escaping (Result, Element) -> Result, remove: @escaping (Result, Element) -> Result) -> Observable<Result> {
        return ArrayFoldingByTwoWayFunction<Self, Result>(base: self, initial: initial, add: add, remove: remove).observable
    }
}

extension ObservableArrayType where Element: IntegerArithmetic & ExpressibleByIntegerLiteral {
    /// Return the (observable) sum of the elements contained in this array.
    public func sum() -> Observable<Element> {
        return reduce(0, add: +, remove: -)
    }
}

private class ArrayFoldingByTwoWayFunction<Base: ObservableArrayType, Value>: AbstractObservableBase<Value> {
    private var _value: Value
    private var _state = TransactionState<ValueChange<Value>>()

    let add: (Value, Base.Element) -> Value
    let remove: (Value, Base.Element) -> Value
    var connection: Connection? = nil

    init(base: Base, initial: Value, add: @escaping (Value, Base.Element) -> Value, remove: @escaping (Value, Base.Element) -> Value) {
        self._value = base.value.reduce(initial, add)
        self.add = add
        self.remove = remove
        super.init()

        connection = base.updates.connect { [unowned self] in self.apply($0) }
    }

    deinit {
        connection!.disconnect()
    }

    private func apply(_ update: ArrayUpdate<Base.Element>) {
        switch update {
        case .beginTransaction:
            _state.begin()
        case .change(let change):
            let old = _value
            change.forEachOld { _value = remove(_value, $0) }
            change.forEachNew { _value = add(_value, $0) }
            _state.send(ValueChange(from: old, to: _value))
        case .endTransaction:
            _state.end()
        }
    }

    override var value: Value { return _value }
    override var updates: ValueUpdateSource<Value> { return _state.source(retaining: self) }
}
