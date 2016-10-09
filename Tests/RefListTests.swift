//
//  RefListTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-08.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
@testable import GlueKit

private final class Fixture: RefListElement {
    var value: Int
    var refListLink = RefListLink<Fixture>()

    init(_ value: Int) { self.value = value }
}

class RefListTests: XCTestCase {
    private func verify(_ list: RefList<Fixture>, file: StaticString = #file, line: UInt = #line) {
        for i in 0 ..< list.count {
            let element = list[i]
            XCTAssertEqual(list.index(of: element), i, file: file, line: line)
        }
    }

    func test_basicOperations() {
        let list = RefList<Fixture>(order: 5)

        // Append even elements.
        for i in 0 ..< 50 {
            list.insert(Fixture(2 * i), at: i)
            verify(list)
        }
        XCTAssertEqual(list.map { $0.value }, (0 ..< 50).map { 2 * $0 })

        // Insert odd elements.
        for i in 0 ..< 50 {
            list.insert(Fixture(2 * i + 1), at: 2 * i + 1)
            verify(list)
        }
        XCTAssertEqual(list.map { $0.value }, Array(0 ..< 100))

        // Look up elements.
        for i in 0 ..< 100 {
            let element = list[i]
            XCTAssertEqual(element.value, i)
        }

        // Remove elements from the start.
        for i in 0 ..< 50 {
            XCTAssertEqual(list.remove(at: 0).value, i)
            verify(list)
        }

        // Remove elements from the end.
        for i in (50 ..< 100).reversed() {
            XCTAssertEqual(list.remove(at: list.count - 1).value, i)
            verify(list)
        }
    }

    func test_remove() {
        for removedIndex in 0 ..< 30 {
            let list = RefList<Fixture>(order: 5)
            for i in 0 ..< 30 { list.insert(Fixture(i), at: i) }
            XCTAssertEqual(list.remove(at: removedIndex).value, removedIndex)
            verify(list)
        }
    }

    func test_leaks() {
        weak var list: RefList<Fixture>? = nil
        weak var test: Fixture? = nil
        do {
            let l = RefList<Fixture>(order: 5)
            for i in 0 ..< 30 { l.insert(Fixture(i), at: i) }
            list = l
            test = l[10]
        }
        XCTAssertNil(list)
        XCTAssertNil(test)
    }

    func test_forEach() {
        let list = RefList<Fixture>(order: 5)
        for i in 0 ..< 100 {
            list.insert(Fixture(i), at: i)
        }

        var i = 0
        list.forEach { e in
            XCTAssertEqual(e.value, i)
            i += 1
        }
        XCTAssertEqual(i, list.count)

        for start in 0 ..< list.count {
            for end in start ..< list.count {
                var i = start
                list.forEach(in: start ..< end) { e in
                    XCTAssertEqual(e.value, i)
                    i += 1
                }
                XCTAssertEqual(i, end)
            }
        }
    }
}
