//
//  Observable Transformations.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

extension ObservableValueType where Change == ValueChange<Value> {
    public func buffered() -> AnyObservableValue<Value> {
        return BufferedObservableValue(self).anyObservableValue
    }
}

private struct BufferedObservableSink<Base: ObservableValueType>: UniqueOwnedSink where Base.Change == ValueChange<Base.Value> {
    typealias Owner = BufferedObservableValue<Base>

    unowned(unsafe) let owner: Owner

    func receive(_ update: ValueUpdate<Base.Value>) {
        owner.apply(update)
    }
}

private class BufferedObservableValue<Base: ObservableValueType>: _BaseObservableValue<Base.Value>
where Base.Change == ValueChange<Base.Value> {
    typealias Value = Base.Value

    private var _base: Base

    private var _value: Value
    private var _pending: Value? = nil

    init(_ base: Base) {
        self._base = base
        self._value = base.value
        super.init()

        _base.updates.add(BufferedObservableSink(owner: self))
    }

    deinit {
        _base.updates.remove(BufferedObservableSink(owner: self))
    }

    func apply(_ update: ValueUpdate<Value>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            _pending = change.new
        case .endTransaction:
            if let pending = _pending {
                let old = _value
                _value = pending
                _pending = nil
                sendChange(.init(from: old, to: _value))
            }
            endTransaction()
        }
    }

    override var value: Value { return _value }
}
