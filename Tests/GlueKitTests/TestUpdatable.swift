//
//  TestUpdatable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

class TestUpdatable: UpdatableType, SignalDelegate {
    typealias Change = TestChange
    typealias Value = Int

    var _state = TransactionState<Change>()
    var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    var value: Value {
        get { return _value }
        set {
            let old = _value
            _state.begin()
            _value = newValue
            _state.send(.init(from: old, to: _value))
            _state.end()
        }
    }

    func begin() {
        _state.begin()
    }

    func end() {
        _state.end()
    }

    func apply(_ update: Update<TestChange>) {
        switch update {
        case .beginTransaction:
            _state.begin()
        case .change(let change):
            change.apply(on: &_value)
            _state.send(change)
        case .endTransaction:
            _state.end()
        }
    }

    var isConnected: Bool { return _state.isConnected }

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        _state.add(sink, with: self)
    }
    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return _state.remove(sink)
    }
}

class TestUpdatableValue<Value>: UpdatableValueType, SignalDelegate {
    typealias Change = ValueChange<Value>

    var _state = TransactionState<Change>()
    var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    var value: Value {
        get { return _value }
        set {
            let old = _value
            _state.begin()
            _value = newValue
            _state.send(.init(from: old, to: _value))
            _state.end()
        }
    }

    func begin() {
        _state.begin()
    }

    func end() {
        _state.end()
    }

    func apply(_ update: Update<Change>) {
        switch update {
        case .beginTransaction:
            _state.begin()
        case .change(let change):
            change.apply(on: &_value)
            _state.send(change)
        case .endTransaction:
            _state.end()
        }
    }

    var isConnected: Bool { return _state.isConnected }

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        _state.add(sink, with: self)
    }
    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return _state.remove(sink)
    }
}
