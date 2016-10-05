//
//  MappedSetTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-05.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
import GlueKit

class MappedSetTests: XCTestCase {
    func test_map_injectiveValueTransform() {
        let set = SetVariable<Int>([0, 2, 3])
        let mappedSet = set.map { "\($0)" }

        XCTAssertFalse(mappedSet.isBuffered)
        XCTAssertEqual(mappedSet.count, 3)
        XCTAssertEqual(mappedSet.value, Set(["0", "2", "3"]))
        XCTAssertEqual(mappedSet.contains("0"), true)
        XCTAssertEqual(mappedSet.contains("1"), false)
        XCTAssertEqual(mappedSet.isSubset(of: []), false)
        XCTAssertEqual(mappedSet.isSubset(of: ["3", "4", "5"]), false)
        XCTAssertEqual(mappedSet.isSubset(of: ["0", "2", "3"]), true)
        XCTAssertEqual(mappedSet.isSubset(of: ["0", "1", "2", "3"]), true)
        XCTAssertEqual(mappedSet.isSuperset(of: []), true)
        XCTAssertEqual(mappedSet.isSuperset(of: ["3"]), true)
        XCTAssertEqual(mappedSet.isSuperset(of: ["0", "2", "3"]), true)
        XCTAssertEqual(mappedSet.isSuperset(of: ["0", "1", "2", "3"]), false)
        XCTAssertEqual(mappedSet.isSuperset(of: ["1"]), false)

        var actualChanges: [String] = []
        var expectedChanges: [String] = []
        let connection = mappedSet.changes.connect { change in
            actualChanges.append("[\(Array(change.removed).sorted().joined(separator: ", "))]/[\(Array(change.inserted).sorted().joined(separator: ", "))]")
        }

        set.insert(1)
        XCTAssertEqual(mappedSet.value, Set(["0", "1", "2", "3"]))
        expectedChanges.append("[]/[1]")
        XCTAssertEqual(actualChanges, expectedChanges)

        set.subtract(Set([1, 2]))
        XCTAssertEqual(mappedSet.value, Set(["0", "3"]))
        expectedChanges.append("[1, 2]/[]")
        XCTAssertEqual(actualChanges, expectedChanges)

        connection.disconnect()
    }

    func test_map_noninjectiveValueTransform() {
        let set = SetVariable<Int>([0, 2, 3, 4, 8, 9])
        let mappedSet = set.map { $0 / 2 }

        XCTAssertEqual(mappedSet.value, [0, 1, 2, 4])

        var actualChanges: [String] = []
        var expectedChanges: [String] = []
        let connection = mappedSet.changes.connect { change in
            let r = Array(change.removed).sorted().map { "\($0)" }.joined(separator: ", ")
            let i = Array(change.inserted).sorted().map { "\($0)" }.joined(separator: ", ")
            actualChanges.append("[\(r)]/[\(i)]")
        }

        set.insert(1)
        XCTAssertEqual(mappedSet.value, [0, 1, 2, 4])
        XCTAssertEqual(actualChanges, expectedChanges) // No change expected

        set.remove(4)
        XCTAssertEqual(mappedSet.value, [0, 1, 4])
        expectedChanges.append("[2]/[]")
        XCTAssertEqual(actualChanges, expectedChanges)

        set.remove(3)
        XCTAssertEqual(mappedSet.value, [0, 1, 4])
        XCTAssertEqual(actualChanges, expectedChanges) // No change expected

        connection.disconnect()
    }

    func test_injectiveMap() {
        let set = SetVariable<Int>([0, 2, 3])
        let mappedSet = set.injectiveMap { "\($0)" }

        XCTAssertTrue(mappedSet.isBuffered)
        XCTAssertEqual(mappedSet.count, 3)
        XCTAssertEqual(mappedSet.value, Set(["0", "2", "3"]))
        XCTAssertEqual(mappedSet.contains("0"), true)
        XCTAssertEqual(mappedSet.contains("1"), false)
        XCTAssertEqual(mappedSet.isSubset(of: []), false)
        XCTAssertEqual(mappedSet.isSubset(of: ["3", "4", "5"]), false)
        XCTAssertEqual(mappedSet.isSubset(of: ["0", "2", "3"]), true)
        XCTAssertEqual(mappedSet.isSubset(of: ["0", "1", "2", "3"]), true)
        XCTAssertEqual(mappedSet.isSuperset(of: []), true)
        XCTAssertEqual(mappedSet.isSuperset(of: ["3"]), true)
        XCTAssertEqual(mappedSet.isSuperset(of: ["0", "2", "3"]), true)
        XCTAssertEqual(mappedSet.isSuperset(of: ["0", "1", "2", "3"]), false)
        XCTAssertEqual(mappedSet.isSuperset(of: ["1"]), false)

        var actualChanges: [String] = []
        var expectedChanges: [String] = []
        let connection = mappedSet.changes.connect { change in
            actualChanges.append("[\(Array(change.removed).sorted().joined(separator: ", "))]/[\(Array(change.inserted).sorted().joined(separator: ", "))]")
        }

        set.insert(1)
        XCTAssertEqual(mappedSet.value, Set(["0", "1", "2", "3"]))
        expectedChanges.append("[]/[1]")
        XCTAssertEqual(actualChanges, expectedChanges)

        set.subtract(Set([1, 2]))
        XCTAssertEqual(mappedSet.value, Set(["0", "3"]))
        expectedChanges.append("[1, 2]/[]")
        XCTAssertEqual(actualChanges, expectedChanges)

        connection.disconnect()
    }
}
