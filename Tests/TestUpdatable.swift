//
//  TestUpdatable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import GlueKit

class TestUpdatable: UpdatableType, Signaler {
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

    func withTransaction<Result>(_ body: () -> Result) -> Result {
        _state.begin()
        defer { _state.end() }
        return body()
    }

    var isConnected: Bool { return _state.isConnected }

    var updates: AnySource<Update<Change>> { return _state.source(retaining: self) }
}

class TestUpdatableValue<Value>: UpdatableValueType, Signaler {
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

    func withTransaction<Result>(_ body: () -> Result) -> Result {
        _state.begin()
        defer { _state.end() }
        return body()
    }

    var isConnected: Bool { return _state.isConnected }

    var updates: AnySource<Update<Change>> { return _state.source(retaining: self) }
}
