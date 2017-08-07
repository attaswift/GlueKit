//
//  Abstract Observables.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

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
