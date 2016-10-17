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
    var _signal = Signal<ValueChange<Value>>()

    var value: Value {
        didSet {
            _signal.send(.init(from: oldValue, to: value))
        }
    }

    init(_ value: Value) {
        self.value = value
    }

    var changes: Source<ValueChange<Value>> { return _signal.source }
}

class TestUpdatable<Value>: UpdatableValueType {
    var _signal = Signal<ValueChange<Value>>()

    var value: Value {
        didSet {
            _signal.send(.init(from: oldValue, to: value))
        }
    }

    init(_ value: Value) {
        self.value = value
    }

    var changes: Source<ValueChange<Value>> { return _signal.source }
}

