//
//  DistinctUnionTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-04.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit

class DistinctUnionTests: XCTestCase {

    func test_getters() {
        let array: ArrayVariable<Int> = [0, 1, 2, 2, 3, 4, 5, 5, 5]
        let set = array.distinctUnion()

        XCTAssertTrue(set.isBuffered)
        XCTAssertEqual(set.count, 6)
        XCTAssertEqual(set.value, Set(0 ..< 6))
        XCTAssertTrue(set.contains(0))
        XCTAssertFalse(set.contains(7))

        XCTAssertTrue(set.isSubset(of: Set(0 ..< 100)))
        XCTAssertTrue(set.isSubset(of: Set(0 ..< 6)))
        XCTAssertFalse(set.isSubset(of: Set(-5 ..< 5)))
        XCTAssertFalse(set.isSubset(of: Set(-5 ..< 0)))

        XCTAssertTrue(set.isSuperset(of: Set(0 ..< 4)))
        XCTAssertTrue(set.isSuperset(of: Set(0 ..< 6)))
        XCTAssertFalse(set.isSuperset(of: Set(-1 ..< 6)))
        XCTAssertFalse(set.isSuperset(of: Set(-1 ..< 3)))
    }

    func test_updates() {
        let array: ArrayVariable<Int> = [0]

        let set = array.distinctUnion()

        let mock = MockSetObserver(set)

        mock.expecting(["begin", "[]/[1]", "end"]) {
            array.append(1)
        }

        mock.expecting(["begin", "[]/[2]", "end"]) {
            array.append(2)
        }
        XCTAssertEqual(set.value, Set([0, 1, 2]))

        mock.expecting(["begin", "end"]) {
            array.append(1)
        }
        XCTAssertEqual(array.value, [0, 1, 2, 1])
        XCTAssertEqual(set.value, Set([0, 1, 2]))

        mock.expecting(["begin", "end"]) {
            _ = array.remove(at: 3)
        }
        XCTAssertEqual(array.value, [0, 1, 2])
        XCTAssertEqual(set.value, Set([0, 1, 2]))

        mock.expecting(["begin", "[1]/[]", "end"]) {
            _ = array.remove(at: 1)
        }
        XCTAssertEqual(array.value, [0, 2])
        XCTAssertEqual(set.value, Set([0, 2]))

        mock.expecting(["begin", "[2]/[3]", "end"]) {
            array[1] = 3
        }
        XCTAssertEqual(array.value, [0, 3])
        XCTAssertEqual(set.value, Set([0, 3]))

        mock.expecting(["begin", "[]/[4, 5, 6]", "end"]) {
            array.append(contentsOf: [4, 4, 4, 5, 5, 6])
        }
        XCTAssertEqual(array.value, [0, 3, 4, 4, 4, 5, 5, 6])
        XCTAssertEqual(set.value, Set([0, 3, 4, 5, 6]))

        mock.expecting(["begin", "[6]/[]", "[4]/[]", "[0]/[]", "end"]) {
            // Remove even values
            array.withTransaction {
                for i in (0 ..< array.count).reversed() {
                    if array[i] & 1 == 0 {
                        array.remove(at: i)
                    }
                }
            }
        }
        XCTAssertEqual(array.value, [3, 5, 5])
        XCTAssertEqual(set.value, Set([3, 5]))

        mock.expecting(["begin", "[3, 5]/[]", "end"]) {
            array.removeAll()
        }
        XCTAssertEqual(set.value, Set())
    }
}
