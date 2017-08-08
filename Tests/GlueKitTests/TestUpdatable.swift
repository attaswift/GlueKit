//
//  TestUpdatable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

class TestUpdatable: UpdatableType, TransactionalThing {
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

    func apply(_ update: Update<TestChange>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            change.apply(on: &_value)
            sendChange(change)
        case .endTransaction:
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

class TestUpdatableValue<Value>: UpdatableValueType, TransactionalThing {
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

    func apply(_ update: Update<Change>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            change.apply(on: &_value)
            sendChange(change)
        case .endTransaction:
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
