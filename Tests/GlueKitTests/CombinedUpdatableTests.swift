//
//  CombinedUpdatableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit


class CombinedUpdatableTests: XCTestCase {
    func testCombine_Works() {
        let a = TestUpdatableValue(0)
        let b = TestUpdatableValue(1)

        let combined = a.combined(b).map({ (a, b) in 10 * a + b }, inverse: { ($0 / 10, $0 % 10) })

        XCTAssertEqual(combined.value, 1)
        combined.value = 12
        XCTAssertEqual(combined.value, 12)

        let changes = combined.changes
        let mock = TransformedMockSink(changes, { "\($0)" })

        mock.expecting("12 -> 32") {
            a.value = 3
        }

        XCTAssertEqual(combined.value, 32)

        mock.expecting("32 -> 34") {
            b.value = 4
        }

        XCTAssertEqual(combined.value, 34)

        mock.expecting("34 -> 56") {
            combined.value = 56
        }
        XCTAssertEqual(combined.value, 56)
        XCTAssertEqual(a.value, 5)
        XCTAssertEqual(b.value, 6)
    }

    func testCombine_WithNestedUpdates() {
        let a = TestUpdatableValue(3)
        let b = TestUpdatableValue(2)
        let combined = a.combined(b)

        var r = ""
        let c = combined.values.subscribe { av, bv in
            r += " (\(av)-\(bv)"
            if av > 0 {
                a.value = av - 1
            }
            else if bv > 0 {
                b.value = bv - 1
            }
            r += ")"
        }

        XCTAssertEqual(r, " (3-2) (2-2) (1-2) (0-2) (0-1) (0-0)")
        c.disconnect()
    }

    func testCombineUpToSixUpdatables() {
        let a = TestUpdatableValue(1)
        let b = TestUpdatableValue(2)
        let c = TestUpdatableValue(3)
        let d = TestUpdatableValue(4)
        let e = TestUpdatableValue(5)
        let f = TestUpdatableValue(6)

        let t2 = a.combined(b)
        let t3 = a.combined(b, c)
        let t4 = a.combined(b, c, d)
        let t5 = a.combined(b, c, d, e)
        let t6 = a.combined(b, c, d, e, f)

        XCTAssertTrue(t2.value == (1, 2))
        XCTAssertTrue(t3.value == (1, 2, 3))
        XCTAssertTrue(t4.value == (1, 2, 3, 4))
        XCTAssertTrue(t5.value == (1, 2, 3, 4, 5))
        XCTAssertTrue(t6.value == (1, 2, 3, 4, 5, 6))

        t6.value = (6, 5, 4, 3, 2, 1)

        XCTAssertTrue(t2.value == (6, 5))
        XCTAssertTrue(t3.value == (6, 5, 4))
        XCTAssertTrue(t4.value == (6, 5, 4, 3))
        XCTAssertTrue(t5.value == (6, 5, 4, 3, 2))
        XCTAssertTrue(t6.value == (6, 5, 4, 3, 2, 1))

        t5.value = (2, 4, 6, 8, 10)

        XCTAssertTrue(t2.value == (2, 4))
        XCTAssertTrue(t3.value == (2, 4, 6))
        XCTAssertTrue(t4.value == (2, 4, 6, 8))
        XCTAssertTrue(t5.value == (2, 4, 6, 8, 10))
        XCTAssertTrue(t6.value == (2, 4, 6, 8, 10, 1))

        t4.value = (3, 5, 7, 11)

        XCTAssertTrue(t2.value == (3, 5))
        XCTAssertTrue(t3.value == (3, 5, 7))
        XCTAssertTrue(t4.value == (3, 5, 7, 11))
        XCTAssertTrue(t5.value == (3, 5, 7, 11, 10))
        XCTAssertTrue(t6.value == (3, 5, 7, 11, 10, 1))

        t3.value = (-1, -2, -3)

        XCTAssertTrue(t2.value == (-1, -2))
        XCTAssertTrue(t3.value == (-1, -2, -3))
        XCTAssertTrue(t4.value == (-1, -2, -3, 11))
        XCTAssertTrue(t5.value == (-1, -2, -3, 11, 10))
        XCTAssertTrue(t6.value == (-1, -2, -3, 11, 10, 1))

        t2.value = (10, 20)

        XCTAssertTrue(t2.value == (10, 20))
        XCTAssertTrue(t3.value == (10, 20, -3))
        XCTAssertTrue(t4.value == (10, 20, -3, 11))
        XCTAssertTrue(t5.value == (10, 20, -3, 11, 10))
        XCTAssertTrue(t6.value == (10, 20, -3, 11, 10, 1))

        a.value = 0

        XCTAssertTrue(t2.value == (0, 20))
        XCTAssertTrue(t3.value == (0, 20, -3))
        XCTAssertTrue(t4.value == (0, 20, -3, 11))
        XCTAssertTrue(t5.value == (0, 20, -3, 11, 10))
        XCTAssertTrue(t6.value == (0, 20, -3, 11, 10, 1))

    }
}
