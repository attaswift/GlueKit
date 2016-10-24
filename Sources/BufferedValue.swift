//
//  Observable Transformations.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableValueType where Change == ValueChange<Value> {
    public func buffered() -> AnyObservableValue<Value> {
        return BufferedObservableValue(self).anyObservable
    }
}

internal class BufferedObservableValue<Base: ObservableValueType>: _AbstractObservableValue<Base.Value>
where Base.Change == ValueChange<Base.Value> {
    typealias Value = Base.Value

    private var _base: Base

    private var _value: Value
    private var _state = TransactionState<BufferedObservableValue>()
    private var _pending: Value? = nil

    init(_ base: Base) {
        self._base = base
        self._value = base.value
        super.init()

        _base.updates.add(MethodSink(owner: self, identifier: 0, method: BufferedObservableValue.apply))
    }

    deinit {
        _base.updates.remove(MethodSink(owner: self, identifier: 0, method: BufferedObservableValue.apply))
    }

    private func apply(_ update: ValueUpdate<Value>) {
        switch update {
        case .beginTransaction:
            _state.begin()
        case .change(let change):
            _pending = change.new
        case .endTransaction:
            if let pending = _pending {
                let old = _value
                _value = pending
                _pending = nil
                _state.send(.init(from: old, to: _value))
            }
            _state.end()
        }
    }

    override var value: Value { return _value }
    override var updates: ValueUpdateSource<Value> { return _state.source(retaining: self) }
}
