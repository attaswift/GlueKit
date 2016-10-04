//
//  DistinctUnionTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-04.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
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

        var received = [String]()
        let connection = set.changes.connect { change in
            received.append("r:\(change.removed.sorted()) i:\(change.inserted.sorted())")
        }

        array.append(1)
        XCTAssertEqual(set.value, Set([0, 1]))
        XCTAssertEqual(received, ["r:[] i:[1]"])

        array.append(2)
        XCTAssertEqual(set.value, Set([0, 1, 2]))
        XCTAssertEqual(received, ["r:[] i:[1]", "r:[] i:[2]"])

        array.append(1)
        XCTAssertEqual(array.value, [0, 1, 2, 1])
        XCTAssertEqual(set.value, Set([0, 1, 2]))
        XCTAssertEqual(received, ["r:[] i:[1]", "r:[] i:[2]"])

        array.remove(at: 3)
        XCTAssertEqual(array.value, [0, 1, 2])
        XCTAssertEqual(set.value, Set([0, 1, 2]))
        XCTAssertEqual(received, ["r:[] i:[1]", "r:[] i:[2]"])

        array.remove(at: 1)
        XCTAssertEqual(array.value, [0, 2])
        XCTAssertEqual(set.value, Set([0, 2]))
        XCTAssertEqual(received, ["r:[] i:[1]", "r:[] i:[2]", "r:[1] i:[]"])

        array[1] = 3
        XCTAssertEqual(array.value, [0, 3])
        XCTAssertEqual(set.value, Set([0, 3]))
        XCTAssertEqual(received, ["r:[] i:[1]", "r:[] i:[2]", "r:[1] i:[]", "r:[2] i:[3]"])

        array.append(contentsOf: [4, 4, 4, 5, 5, 6])
        XCTAssertEqual(array.value, [0, 3, 4, 4, 4, 5, 5, 6])
        XCTAssertEqual(set.value, Set([0, 3, 4, 5, 6]))
        XCTAssertEqual(received, ["r:[] i:[1]", "r:[] i:[2]", "r:[1] i:[]", "r:[2] i:[3]", "r:[] i:[4, 5, 6]"])

        // Remove even values
        array.modify { array in
            for i in (0 ..< array.count).reversed() {
                if array[i] & 1 == 0 {
                    array.remove(at: i)
                }
            }
        }
        XCTAssertEqual(array.value, [3, 5, 5])
        XCTAssertEqual(set.value, Set([3, 5]))
        XCTAssertEqual(received, ["r:[] i:[1]", "r:[] i:[2]", "r:[1] i:[]", "r:[2] i:[3]", "r:[] i:[4, 5, 6]", "r:[0, 4, 6] i:[]"])

        connection.disconnect()

        array.removeAll()
        XCTAssertEqual(set.value, Set())
    }
}
