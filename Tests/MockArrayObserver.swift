//
//  MockArrayObserver.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-06.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
import GlueKit

class MockArrayObserver<Element: Equatable>: SinkType {
    var context: [(StaticString, UInt)]
    var expectations: [(ArrayChange<Element>, StaticString, UInt)] = []

    init(file: StaticString = #file, line: UInt = #line) {
        self.context = [(file, line)]
    }

    func receive(_ change: ArrayChange<Element>) -> Void {
        self.process(change)
    }

    func expect(_ change: ArrayChange<Element>, file: StaticString = #file, line: UInt = #line) {
        expectations.append((change, file, line))
    }

    func expect<R>(_ change: ArrayChange<Element>, file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        self.context.append(file, line)
        defer { self.context.removeLast() }
        self.expect(change, file: file, line: line)
        return try body()
    }

    func expectFulfilled() {
        for (change, file, line) in expectations {
            XCTFail("Expectation \(change) not fulfilled", file: file, line: line)
        }
        expectations.removeAll()
    }

    func process(_ change: ArrayChange<Element>) {
        guard !expectations.isEmpty else {
            XCTFail("Unexpected change: \(change)", file: context.last!.0, line: context.last!.1)
            return
        }
        let expected = expectations.removeFirst()
        XCTAssertTrue(expected.0 == change, "Expected \(expected.0), got \(change)", file: expected.1, line: expected.2)
    }
}

