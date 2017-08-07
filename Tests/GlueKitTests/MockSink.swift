//
//  MockSink.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-10.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit

class MockSinkState<Value, Output: Equatable> {
    let transform: (Value) -> Output
    var isExpecting = false
    var expected: [[Output]] = []
    var actual: [Output] = []
    var connection: Connection?

    init(_ transform: @escaping (Value) -> Output) {
        self.connection = nil
        self.transform = transform
    }

    init(_ connection: Connection, _ transform: @escaping (Value) -> Output) {
        self.connection = connection
        self.transform = transform
    }

    deinit {
        connection?.disconnect()
    }

    func receive(_ input: Value) {
        if !isExpecting {
            XCTFail("Sink received unexpected value: \(input)")
        }
        else {
            actual.append(transform(input))
        }
    }

    func run<R>(file: StaticString, line: UInt, _ body: () throws -> R) rethrows -> R {
        isExpecting = true
        defer {
            switch expected.count {
            case 0:
                XCTAssertEqual(actual, [], file: file, line: line)
            case 1:
                XCTAssertEqual(actual, expected[0], file: file, line: line)
            default:
                XCTAssertTrue(expected.contains(where: { actual == $0 }), "Unexpected values received: \(actual)", file: file, line: line)
            }

            actual = []
            expected = []
            isExpecting = false
        }
        return try body()
    }

    func disconnect() {
        connection?.disconnect()
        connection = nil
    }
}

protocol MockSinkProtocol: class, SinkType {
    associatedtype Output: Equatable
    var state: MockSinkState<Value, Output> { get }
}

extension MockSinkProtocol {
    @discardableResult
    func expectingNothing<R>(file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        precondition(state.expected.isEmpty)
        return try state.run(file: file, line: line, body)
    }

    @discardableResult
    func expecting<R>(_ value: Output, file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        precondition(state.expected.isEmpty)
        state.expected = [[value]]
        return try state.run(file: file, line: line, body)
    }

    @discardableResult
    func expecting<R>(_ values: [Output], file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        precondition(state.expected.isEmpty)
        state.expected = [values]
        return try state.run(file: file, line: line, body)
    }

    @discardableResult
    func expectingOneOf<R>(_ values: [[Output]], file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        precondition(state.expected.isEmpty)
        state.expected = values
        return try state.run(file: file, line: line, body)
    }


    func subscribe<Source: SourceType>(to source: Source) where Source.Value == Value {
        precondition(state.connection == nil)
        state.connection = source.subscribe { [unowned self] (input: Value) -> Void in self.receive(input) }
    }

    func disconnect() {
        state.disconnect()
    }
}


class TransformedMockSink<Value, Output: Equatable>: MockSinkProtocol {
    let state: MockSinkState<Value, Output>

    init(_ transform: @escaping (Value) -> Output) {
        self.state = .init(transform)
    }

    init<Source: SourceType>(_ source: Source, _ transform: @escaping (Value) -> Output) where Source.Value == Value {
        self.state = .init(transform)
        self.subscribe(to: source)
    }

    func receive(_ input: Value) {
        state.receive(input)
    }
}

class MockSink<Value: Equatable>: MockSinkProtocol {
    let state: MockSinkState<Value, Value>

    init() {
        self.state = .init({ $0 })
    }

    init<Source: SourceType>(_ source: Source) where Source.Value == Value {
        self.state = .init({ $0 })
        self.subscribe(to: source)
    }

    func receive(_ input: Value) {
        state.receive(input)
    }
}
