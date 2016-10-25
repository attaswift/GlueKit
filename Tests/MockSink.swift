//
//  MockSink.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-10.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
import GlueKit

class MockSink<Value: Equatable>: SinkType {
    var isExpecting = false
    var expected: [Value] = []
    var actual: [Value] = []

    var connection: Connection? = nil

    init() {
    }

    init<Source: SourceType>(_ source: Source) where Source.Value == Value {
        self.connection = source.connect { [unowned self] value in self.actual.append(value) }
    }

    deinit {
        self.connection?.disconnect()
    }

    func receive(_ value: Value) {
        if !isExpecting {
            XCTFail("Sink received unexpected value: \(value)")
        }
        else {
            self.actual.append(value)
        }
    }

    func expectingNothing<R>(file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        return try run(file: file, line: line, body)
    }

    func expecting<R>(_ value: Value, file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        expected.append(value)
        return try run(file: file, line: line, body)
    }

    func expecting<R>(_ values: [Value], file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        expected.append(contentsOf: values)
        return try run(file: file, line: line, body)
    }

    private func run<R>(file: StaticString, line: UInt, _ body: () throws -> R) rethrows -> R {
        isExpecting = true
        defer {
            XCTAssertEqual(actual, expected, file: file, line: line)
            actual = []
            expected = []
            isExpecting = false
        }
        return try body()
    }
}
