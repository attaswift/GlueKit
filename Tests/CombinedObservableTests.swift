//
//  CombinedObservableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
import GlueKit

class CombinedObservableTests: XCTestCase {
    func testCombine_Works() {
        let a = TestObservable(1)
        let b = TestObservable(2)

        let combined = a.combined(b) { a, b in "\(a),\(b)" }

        let mock = MockValueObserver(combined)

        mock.expecting(.init(from: "1,2", to: "3,2")) {
            a.value = 3
        }

        XCTAssertEqual(combined.value, "3,2")

        mock.expecting(.init(from: "3,2", to: "3,4")) {
            b.value = 4
        }

        XCTAssertEqual(combined.value, "3,4")
    }

    func testCombineDistinct_WithNestedUpdates() {
        let a = TestObservable(3)
        let b = TestObservable(2)
        let combined = a.combined(b) { a, b in (a, b) }.distinct(==)

        var r = ""
        let c = combined.values.connect { av, bv in
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

    func testCombineUpToSixObservables() {
        let a = TestObservable(1)
        let b = TestObservable(2)
        let c = TestObservable(3)
        let d = TestObservable(4)
        let e = TestObservable(5)
        let f = TestObservable(6)

        let t2 = a.combined(b)
        let t3 = a.combined(b, c)
        let t4 = a.combined(b, c, d)
        let t5 = a.combined(b, c, d, e)
        let t6 = a.combined(b, c, d, e, f)

        let c2 = a.combined(b, via: +)
        let c3 = a.combined(b, c, via: { $0 + $1 + $2 })
        let c4 = a.combined(b, c, d, via: { $0 + $1 + $2 + $3 })
        let c5 = a.combined(b, c, d, e, via: { $0 + $1 + $2 + $3 + $4 })
        let c6 = a.combined(b, c, d, e, f, via: { $0 + $1 + $2 + $3 + $4 + $5 })

        XCTAssertTrue(t2.value == (1, 2))
        XCTAssertTrue(t3.value == (1, 2, 3))
        XCTAssertTrue(t4.value == (1, 2, 3, 4))
        XCTAssertTrue(t5.value == (1, 2, 3, 4, 5))
        XCTAssertTrue(t6.value == (1, 2, 3, 4, 5, 6))

        XCTAssertTrue(c2.value == 3)
        XCTAssertTrue(c3.value == 6)
        XCTAssertTrue(c4.value == 10)
        XCTAssertTrue(c5.value == 15)
        XCTAssertTrue(c6.value == 21)
    }

    func testEquatableOperators() {
        let a = TestObservable(0)
        let b = TestObservable(0)

        let eq = (a == b)
        let ne = (a != b)

        XCTAssertTrue(eq.value)
        XCTAssertFalse(ne.value)

        a.value = 1

        XCTAssertFalse(eq.value)
        XCTAssertTrue(ne.value)
    }

    func testComparableOperators() {
        let a = TestObservable(0)
        let b = TestObservable(0)

        let lt = (a < b)
        let gt = (a > b)
        let le = (a <= b)
        let ge = (a >= b)
        let mi = min(a, b)
        let ma = max(a, b)

        XCTAssertFalse(lt.value)
        XCTAssertFalse(gt.value)
        XCTAssertTrue(le.value)
        XCTAssertTrue(ge.value)
        XCTAssertEqual(mi.value, 0)
        XCTAssertEqual(ma.value, 0)

        a.value = 1

        XCTAssertFalse(lt.value)
        XCTAssertTrue(gt.value)
        XCTAssertFalse(le.value)
        XCTAssertTrue(ge.value)
        XCTAssertEqual(mi.value, 0)
        XCTAssertEqual(ma.value, 1)

        b.value = 2

        XCTAssertTrue(lt.value)
        XCTAssertFalse(gt.value)
        XCTAssertTrue(le.value)
        XCTAssertFalse(ge.value)
        XCTAssertEqual(mi.value, 1)
        XCTAssertEqual(ma.value, 2)

        a.value = 2

        XCTAssertFalse(lt.value)
        XCTAssertFalse(gt.value)
        XCTAssertTrue(le.value)
        XCTAssertTrue(ge.value)
        XCTAssertEqual(mi.value, 2)
        XCTAssertEqual(ma.value, 2)
    }

    func testBooleanOperators() {
        let a = TestUpdatable(0)
        let b = TestUpdatable(0)
        let c = TestUpdatable(0)

        let bIsBetweenAAndC = a < b && b < c
        let bIsNotBetweenAAndC = !bIsBetweenAAndC
        let aIsNotTheGreatest = a < b || a < c

        XCTAssertFalse(bIsBetweenAAndC.value)
        XCTAssertTrue(bIsNotBetweenAAndC.value)
        XCTAssertFalse(aIsNotTheGreatest.value)

        a.value = 1

        XCTAssertFalse(bIsBetweenAAndC.value)
        XCTAssertTrue(bIsNotBetweenAAndC.value)
        XCTAssertFalse(aIsNotTheGreatest.value)

        b.value = 2

        XCTAssertFalse(bIsBetweenAAndC.value)
        XCTAssertTrue(bIsNotBetweenAAndC.value)
        XCTAssertTrue(aIsNotTheGreatest.value)

        c.value = 3

        XCTAssertTrue(bIsBetweenAAndC.value)
        XCTAssertFalse(bIsNotBetweenAAndC.value)
        XCTAssertTrue(aIsNotTheGreatest.value)
    }

    func testIntegerNegation() {
        let a = TestUpdatable(1)

        let n = -a

        XCTAssertEqual(n.value, -1)

        let mock = MockValueObserver(n)

        mock.expecting(.init(from: -1, to: -2)) {
            a.value = 2
        }
    }

    func testIntegerArithmeticOperators() {
        let a = TestUpdatable(0)
        let b = TestUpdatable(0)
        let c = TestUpdatable(0)

        let e1 = a % AnyObservableValue.constant(10)
        let e2 = b * c / (a + AnyObservableValue.constant(1))
        let expression = e1 + e2 - c

        var r = [Int]()
        let connection = expression.values.connect { r.append($0) }

        XCTAssertEqual(r, [0])
        r = []

        a.value = 1

        // The observable 'a' occurs twice in the expression above, so the expression will be evaluated twice.
        // The first evaluation will only apply the new value to one of the sources.
        XCTAssertEqual(r, [1])

        r = []

        b.value = 2

        XCTAssertEqual(r, [1])
        r = []
        
        c.value = 3
        
        XCTAssertEqual(r, [1 + 2 * 3 / 2 - 3] as [Int])
        r = []
        
        a.value = 15
        
        XCTAssertEqual(r, [5 + 2 * 3 / 16 - 3] as [Int])
        r = []
        
        
        connection.disconnect()
    }

    func testFloatingPointArithmeticOperators() {
        let a = TestUpdatable(0.0)
        let b = TestUpdatable(0.0)
        let c = TestUpdatable(0.0)

        let expression = a + b * c / (a + AnyObservableValue.constant(1)) - c

        XCTAssertEqual(expression.value, 0)

        var r: [Double] = []
        let connection = expression.values.connect { r.append($0) }

        XCTAssertEqual(r, [0])
        r = []

        a.value = 1

        XCTAssertEqual(r, [1])

        r = []

        b.value = 2

        XCTAssertEqual(r, [1])
        r = []

        c.value = 3

        XCTAssertEqual(r, [1 + 2 * 3 / 2 - 3] as [Double])
        r = []

        a.value = 15

        XCTAssertEqual(r, [15 + 2 * 3 / 16 - 3] as [Double])
        r = []
        
        connection.disconnect()
    }

}

