//
//  ValueChangeTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-27.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class ValueChangeTests: XCTestCase {

    func test() {
        let change = ValueChange<Int>(from: 1, to: 2)
        XCTAssertEqual(change.old, 1)
        XCTAssertEqual(change.new, 2)
        XCTAssertFalse(change.isEmpty)

        var value = 1
        change.apply(on: &value)
        XCTAssertEqual(value, 2)

        XCTAssertEqual(change.applied(on: 1), 2)

        var m = ValueChange(from: 0, to: 1)
        m.merge(with: change)
        XCTAssertEqual(m.old, 0)
        XCTAssertEqual(m.new, 2)

        let m2 = ValueChange(from: 0, to: 1).merged(with: change)
        XCTAssertEqual(m2.old, 0)
        XCTAssertEqual(m2.new, 2)

        let reversed = change.reversed()
        XCTAssertEqual(reversed.old, 2)
        XCTAssertEqual(reversed.new, 1)

        let transformed = change.map { 2 * $0 }
        XCTAssertEqual(transformed.old, 2)
        XCTAssertEqual(transformed.new, 4)

        XCTAssertTrue(change == ValueChange(from: 1, to: 2))
        XCTAssertFalse(change == ValueChange(from: 0, to: 2))
        XCTAssertFalse(change == ValueChange(from: 1, to: 4))

        XCTAssertFalse(change != ValueChange(from: 1, to: 2))
        XCTAssertTrue(change != ValueChange(from: 0, to: 2))
        XCTAssertTrue(change != ValueChange(from: 1, to: 4))
    }
}
