//
//  AccumulatedSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2017-04-23.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension SourceType {
    public func accumulated<R>(_ initial: R, _ next: @escaping (R, Value) -> R) -> AnyObservableValue<R> {
        return AccumulatedSource(self, initial, next).anyObservableValue
    }

    public func counted() -> AnyObservableValue<Int> {
        return accumulated(0) { value, _ in value + 1 }
    }
}

private class AccumulatedSource<Value, S>: _BaseObservableValue<Value> where S: SourceType {
    let source: S
    let next: (Value, S.Value) -> Value
    var _value: Value

    struct Sink<R, S: SourceType>: UniqueOwnedSink {
        typealias Owner = AccumulatedSource<R, S>
        unowned(unsafe) let owner: Owner
        func receive(_ value: S.Value) {
            owner.beginTransaction()
            let old = owner._value
            let new = owner.next(owner._value, value)
            owner._value = new
            owner.sendChange(ValueChange(from: old, to: new))
            owner.endTransaction()
        }
    }

    init(_ source: S, _ initial: Value, _ next: @escaping (Value, S.Value) -> Value) {
        self.source = source
        self.next = next
        self._value = initial
        super.init()
        source.add(Sink<Value, S>(owner: self))
    }

    deinit {
        source.remove(Sink<Value, S>(owner: self))
    }

    override var value: Value { return _value }
}
