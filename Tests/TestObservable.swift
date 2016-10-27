//
//  TestObservable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import GlueKit

class TestObservable: ObservableType, SignalDelegate {
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

    var isConnected: Bool { return _state.isConnected }

    var updates: AnySource<Update<Change>> { return _state.source(delegate: self) }
}

class TestObservableValue<Value>: ObservableValueType, SignalDelegate {
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

    var isConnected: Bool { return _state.isConnected }

    var updates: AnySource<Update<Change>> { return _state.source(delegate: self) }
}
