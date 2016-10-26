//
//  Abstract Observables.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

internal struct TestChange: ChangeType {
    typealias Value = Int

    var values: [Int]

    init(_ values: [Int]) {
        self.values = values
    }

    init(from oldValue: Int, to newValue: Int) {
        values = [oldValue, newValue]
    }

    var isEmpty: Bool {
        return values.isEmpty
    }

    func apply(on value: inout Int) {
        XCTAssertEqual(value, values.first!)
        value = values.last!
    }

    mutating func merge(with next: TestChange) {
        XCTAssertEqual(self.values.last!, next.values.first!)
        values += next.values.dropFirst()
    }

    func reversed() -> TestChange {
        return TestChange(values.reversed())
    }
}

class ChangeTests: XCTestCase {
    func testDefaultApplied() {
        let change = TestChange([1, 2])
        XCTAssertEqual(change.applied(on: 1), 2)
    }

    func testDefaultMerged() {
        let change = TestChange([1, 2])
        let next = TestChange([2, 3])
        XCTAssertEqual(change.merged(with: next).values, [1, 2, 3])
    }
}
