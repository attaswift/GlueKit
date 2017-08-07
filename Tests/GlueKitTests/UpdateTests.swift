//
//  UpdateTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class UpdateTests: XCTestCase {
    func testChangeExtraction() {
        let change = TestChange([1, 2, 3])
        let updates: [Update<TestChange>] = [
            .beginTransaction,
            .change(change),
            .endTransaction,
        ]
        let expected: [String] = ["nil", "1 -> 2 -> 3", "nil"]
        let actual = updates.map { update -> String in
            if let change = update.change {
                return "\(change)"
            }
            else {
                return "nil"
            }
        }
        XCTAssertEqual(actual, expected)
    }

    func testFilter() {
        let change = TestChange([1, 2, 3])
        let updates: [Update<TestChange>] = [
            .beginTransaction,
            .change(change),
            .endTransaction,
            ]
        let expected1: [String] = ["begin", "1 -> 2 -> 3", "end"]
        let actual1 = updates.map { describe($0.filter { _ in true }) }
        XCTAssertEqual(actual1, expected1)

        let expected2: [String] = ["begin", "nil", "end"]
        let actual2 = updates.map { describe($0.filter { _ in false }) }
        XCTAssertEqual(actual2, expected2)
    }

    func testMap() {
        let change = TestChange([1, 2, 3])
        let updates: [Update<TestChange>] = [
            .beginTransaction,
            .change(change),
            .endTransaction,
            ]

        let expected: [String] = ["begin", "2 -> 4 -> 6", "end"]
        let actual = updates.map { describe($0.map { TestChange($0.values.map { 2 * $0 }) }) }
        XCTAssertEqual(actual, expected)
    }
}
