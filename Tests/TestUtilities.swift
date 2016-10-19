//
//  TestUtilities.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-03.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import Foundation
@testable import GlueKit

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
    var _state = TransactionState<ValueChange<Value>>()
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

    var updates: ValueUpdateSource<Value> { return _state.source(retaining: self) }
}

class TestUpdatable<Value>: UpdatableValueType {
    var _state = TransactionState<ValueChange<Value>>()
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

    func withTransaction<Result>(_ body: () -> Result) -> Result {
        _state.begin()
        defer { _state.end() }
        return body()
    }

    var updates: ValueUpdateSource<Value> { return _state.source(retaining: self) }
}
