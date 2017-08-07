//
//  CombinedObservableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit

class CombinedObservableTests: XCTestCase {
    func testCombine_Works() {
        let a = TestObservableValue(1)
        let b = TestObservableValue(2)

        let combined = a.combined(b) { a, b in "[\(a),\(b)]" }

        let mock = MockValueUpdateSink(combined)

        mock.expecting(["begin", "[1,2] -> [3,2]", "end"]) {
            a.value = 3
        }

        XCTAssertEqual(combined.value, "[3,2]")

        mock.expecting(["begin", "[3,2] -> [3,4]", "end"]) {
            b.value = 4
        }

        XCTAssertEqual(combined.value, "[3,4]")
    }

    func testCombineDistinct_WithNestedUpdates() {
        let a = TestObservableValue(3)
        let b = TestObservableValue(2)
        let combined = a.combined(b) { a, b in (a, b) }.distinct(==)

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

    func testCombineUpToSixObservables() {
        let a = TestObservableValue(1)
        let b = TestObservableValue(2)
        let c = TestObservableValue(3)
        let d = TestObservableValue(4)
        let e = TestObservableValue(5)
        let f = TestObservableValue(6)

        let t2 = a.combined(b)
        let t3 = a.combined(b, c)
        let t4 = a.combined(b, c, d)
        let t5 = a.combined(b, c, d, e)
        let t6 = a.combined(b, c, d, e, f)

        let c2 = a.combined(b, by: { (a: Int, b: Int) -> Int in a + b })
        let c3 = a.combined(b, c, by: { (a: Int, b: Int, c: Int) -> Int in a + b + c })
        let c4 = a.combined(b, c, d, by: { (a: Int, b: Int, c: Int, d: Int) -> Int in a + b + c + d })
        let c5 = a.combined(b, c, d, e, by: { (a: Int, b: Int, c: Int, d: Int, e: Int) -> Int in a + b + c + d + e })
        let c6 = a.combined(b, c, d, e, f, by: { (a: Int, b: Int, c: Int, d: Int, e: Int, f: Int) -> Int in a + b + c + d + e + f })

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
        let a = TestObservableValue(0)
        let b = TestObservableValue(0)

        let eq = (a == b)
        let ne = (a != b)

        XCTAssertTrue(eq.value)
        XCTAssertFalse(ne.value)

        a.value = 1

        XCTAssertFalse(eq.value)
        XCTAssertTrue(ne.value)
    }

    func testComparableOperators() {
        let a = TestObservableValue(0)
        let b = TestObservableValue(0)

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
        let a = TestUpdatableValue(0)
        let b = TestUpdatableValue(0)
        let c = TestUpdatableValue(0)

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
        let a = TestUpdatableValue(1)

        let n = -a

        XCTAssertEqual(n.value, -1)

        let mock = MockValueUpdateSink(n)

        mock.expecting(["begin", "-1 -> -2", "end"]) {
            a.value = 2
        }
    }

    func testIntegerArithmeticOperators() {
        let a = TestUpdatableValue(0)
        let b = TestUpdatableValue(0)
        let c = TestUpdatableValue(0)

        let e1 = a % AnyObservableValue.constant(10)
        let e2 = b * c / (a + AnyObservableValue.constant(1))
        let expression = e1 + e2 - c

        var r = [Int]()
        let connection = expression.values.subscribe { r.append($0) }

        XCTAssertEqual(r, [0])
        r = []

        a.value = 1

        // The observable `a` occurs twice in the expression above, so the expression will be evaluated twice.
        // The first evaluation will only apply the new value to one of the sources.
        // However, the `values` source reports only full transactions, so such partial updates will not appear there.
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
        let a = TestUpdatableValue(0.0)
        let b = TestUpdatableValue(0.0)
        let c = TestUpdatableValue(0.0)

        let expression = a + b * c / (a + AnyObservableValue.constant(1)) - c

        XCTAssertEqual(expression.value, 0)

        var r: [Double] = []
        let connection = expression.values.subscribe { r.append($0) }

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

    func testTransactions() {
        let a = Variable<Int>(0)

        let sum = a + a

        let sink = MockValueUpdateSink(sum)

        sink.expecting(["begin", "0 -> 1", "1 -> 2", "end"]) {
            a.value = 1
        }

        sink.expecting("begin") {
            a.apply(.beginTransaction)
        }

        sink.expecting(["2 -> 3", "3 -> 4"]) {
            a.value = 2
        }

        sink.expecting("end") {
            a.apply(.endTransaction)
        }

        sink.disconnect()
    }
}

