//
//  TestUpdatable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
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

    var updates: AnySource<Update<Change>> { return _state.source(delegate: self) }
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

    var updates: AnySource<Update<Change>> { return _state.source(delegate: self) }
}
