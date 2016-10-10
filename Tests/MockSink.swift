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

class MockSink<Value: Equatable> {
    var expected: [Value] = []
    var actual: [Value] = []

    var connection: Connection? = nil

    init<S: SourceType>(_ source: S) where S.SourceValue == Value {
        self.connection = source.connect { [unowned self] value in self.actual.append(value) }
    }

    deinit {
        self.connection!.disconnect()
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
        let result = try body()
        XCTAssertEqual(actual, expected, file: file, line: line)
        actual = []
        expected = []
        return result
    }
}
