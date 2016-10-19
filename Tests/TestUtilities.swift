//
//  TestUtilities.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-03.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import Foundation
import GlueKit

@inline(never)
func noop<Value>(_ value: Value) {
}

func XCTAssertEqual<E: Equatable>(_ a: @autoclosure () -> [[E]], _ b: @autoclosure () -> [[E]], message: String? = nil, file: StaticString = #file, line: UInt = #line) {
    let av = a()
    let bv = b()
    if !av.elementsEqual(bv, by: ==) {
        XCTFail(message ?? "\(av) is not equal to \(bv)", file: file, line: line)
    }
}

class TestObservable<Value>: ObservableValueType {
    var _signal = Signal<ValueUpdate<Value>>()
    var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    var value: Value {
        get { return _value }
        set {
            let old = _value
            _signal.send(.beginTransaction)
            _value = newValue
            _signal.send(.change(.init(from: old, to: _value)))
            _signal.send(.endTransaction)
        }
    }

    var updates: Source<ValueUpdate<Value>> { return _signal.source }
}

class TestUpdatable<Value>: UpdatableValueType {
    var _signal = Signal<ValueUpdate<Value>>()
    var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    func get() -> Value {
        return _value
    }

    func update(_ body: (Value) -> Value) {
        let old = _value
        _signal.send(.beginTransaction)
        _value = body(_value)
        _signal.send(.change(.init(from: old, to: _value)))
        _signal.send(.endTransaction)
    }

    var updates: Source<ValueUpdate<Value>> { return _signal.source }
}
