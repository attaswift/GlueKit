//
//  TestObservable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

class TestObservable: ObservableType, TransactionalThing {
    typealias Change = TestChange
    typealias Value = Int

    var _signal: TransactionalSignal<TestChange>? = nil
    var _transactionCount: Int = 0
    var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    var value: Value {
        get { return _value }
        set {
            let old = _value
            beginTransaction()
            _value = newValue
            sendChange(.init(from: old, to: _value))
            endTransaction()
        }
    }

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        signal.add(sink)
    }
    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return signal.remove(sink)
    }
}

class TestObservableValue<Value>: ObservableValueType, TransactionalThing {
    typealias Change = ValueChange<Value>

    var _signal: TransactionalSignal<ValueChange<Value>>? = nil
    var _transactionCount: Int = 0
    var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    var value: Value {
        get { return _value }
        set {
            let old = _value
            beginTransaction()
            _value = newValue
            sendChange(.init(from: old, to: _value))
            endTransaction()
        }
    }

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        signal.add(sink)
    }
    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return signal.remove(sink)
    }
}
