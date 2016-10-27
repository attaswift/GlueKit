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

class TransformedMockSink<Value, Output: Equatable>: SinkType {
    let transform: (Value) -> Output

    var isExpecting = false
    var expected: [Output] = []
    var actual: [Output] = []

    var connection: Connection? = nil

    init(_ transform: @escaping (Value) -> Output) {
        self.transform = transform
    }

    init<Source: SourceType>(_ source: Source, _ transform: @escaping (Value) -> Output) where Source.Value == Value {
        self.transform = transform
        self.connection = source.connect { [unowned self] input in self.receive(input) }
    }

    deinit {
        self.connection?.disconnect()
    }

    func disconnect() {
        self.connection?.disconnect()
        self.connection = nil
    }

    func receive(_ input: Value) {
        if !isExpecting {
            XCTFail("Sink received unexpected value: \(input)")
        }
        else {
            self.actual.append(transform(input))
        }
    }

    @discardableResult
    func expectingNothing<R>(file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        return try run(file: file, line: line, body)
    }

    @discardableResult
    func expecting<R>(_ value: Output, file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        expected.append(value)
        return try run(file: file, line: line, body)
    }

    @discardableResult
    func expecting<R>(_ values: [Output], file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
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

class MockSink<Value: Equatable>: TransformedMockSink<Value, Value> {
    init() {
        super.init({ $0 })
    }

    init<Source: SourceType>(_ source: Source) where Source.Value == Value {
        super.init(source, { $0 })
    }
}
