//
//  Observable Transformations.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableValueType where Change == ValueChange<Value> {
    public func buffered() -> Observable<Value> {
        return BufferedObservableValue(self).observable
    }
}

internal class BufferedObservableValue<Base: ObservableValueType>: AbstractObservableBase<Base.Value>
where Base.Change == ValueChange<Base.Value> {
    typealias Value = Base.Value

    private var _base: Base

    private var _value: Base.Value
    private var _state = TransactionState<Change>()
    private var _pending: Value? = nil
    private var _connection: Connection? = nil

    init(_ base: Base) {
        self._base = base
        self._value = base.value
        super.init()

        self._connection = base.updates.connect { [unowned self] update in self.apply(update) }
    }

    deinit {
        _connection!.disconnect()
    }

    private func apply(_ update: ValueUpdate<Value>) {
        switch update {
        case .beginTransaction:
            _state.begin()
        case .change(let change):
            _pending = change.new
        case .endTransaction:
            if let pending = _pending {
                _value = pending
                _pending = nil
            }
        }
    }

    override var value: Base.Value { return _value }
    override var updates: ValueUpdateSource<Value> { return _state.source(retaining: self) }
}

