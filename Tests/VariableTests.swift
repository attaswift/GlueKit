//
//  VariableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-01.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import GlueKit

class VariableTests: XCTestCase {
    func testValuesSource() {
        let v = Variable<Int>(0)

        var r = [Int]()
        let c = v.values.connect { value in r.append(value) }

        XCTAssertEqual(r, [0], "The values source should trigger immediately with the current value of the variable")

        v.value = 1
        XCTAssertEqual(r, [0, 1])

        v.value = 2
        XCTAssertEqual(r, [0, 1, 2])

        v.value = 2
        XCTAssertEqual(r, [0, 1, 2, 2])

        v.withTransaction {
            v.value = 3
            v.value = 3
        }
        XCTAssertEqual(r, [0, 1, 2, 2, 3])

        v.sink.receive(4)
        XCTAssertEqual(r, [0, 1, 2, 2, 3, 4])
        
        c.disconnect()
    }

    func testFutureValuesSource() {
        let v = Variable<Int>(0)

        var r = [Int]()
        let c = v.futureValues.connect { value in r.append(value) }

        XCTAssertEqual(r, [], "The future values source should not trigger with the current value of the variable")

        v.value = 1
        XCTAssertEqual(r, [1])

        v.value = 2
        XCTAssertEqual(r, [1, 2])

        v.value = 2
        XCTAssertEqual(r, [1, 2, 2])

        v.withTransaction {
            v.value = 3
            v.value = 3
        }
        XCTAssertEqual(r, [1, 2, 2, 3])

        v.sink.receive(4)
        XCTAssertEqual(r, [1, 2, 2, 3, 4])

        c.disconnect()
    }

    func testNestedUpdatesWithTheImmediateSource() {
        let v = Variable<Int>(3)

        var s = ""
        let c = v.values.connect { i in
            s += " (\(i)"
            if i > 0 {
                // This is OK as long as it doesn't lead to infinite updates.
                // The value is updated immediately, but the source is triggered later, at the end of the outermost update.
                v.value -= 1
            }
            s += ")"
        }
        XCTAssertEqual(s, " (3) (2) (1) (0)") // No nesting, all updates are received

        s = ""
        v.value = 1
        XCTAssertEqual(s, " (1) (0)")

        c.disconnect()
    }

    func testNestedUpdatesWithTheFutureSource() {
        let v = Variable<Int>(0)

        var s = ""
        let c = v.futureValues.connect { i in
            s += " (\(i)"
            if i > 0 {
                // This is OK as long as it doesn't lead to infinite updates.
                // The value is updated immediately, but the source is triggered later, at the end of the outermost update.
                v.value -= 1
            }
            s += ")"
        }

        XCTAssertEqual(s, "")

        v.value = 3
        XCTAssertEqual(s, " (3) (2) (1) (0)") // No nesting, all updates are received

        s = ""
        v.value = 1
        XCTAssertEqual(s, " (1) (0)")

        c.disconnect()
    }


    func testReentrantSinks() {
        let v = Variable<Int>(0)

        var s = String()
        let c1 = v.values.connect { i in
            s += " (\(i)"
            if i > 0 {
                v.value = i - 1
            }
            s += ")"
        }
        let c2 = v.values.connect { i in
            s += " (\(i)"
            if i > 0 {
                v.value = i - 1
            }
            s += ")"
        }

        XCTAssertEqual(s, " (0) (0)")

        s = ""
        v.value = 2

        XCTAssertEqual(s, " (2) (2) (1) (1) (1) (1) (0) (0) (0) (0) (0) (0) (0) (0)")

        c1.disconnect()
        c2.disconnect()
    }

    func testExerciseVariables() {
        func check<V: UpdatableValueType>(_ v: V, _ a: V.Value, _ b: V.Value, _ c: V.Value)
        where V.Value: Equatable, V.Change == ValueChange<V.Value> {
            check(v, a, b, c, ==)
        }

        func check<V: UpdatableValueType>(_ v: V, _ a: V.Value, _ b: V.Value, _ c: V.Value, _ eq: @escaping (V.Value, V.Value) -> Bool)
        where V.Change == ValueChange<V.Value> {

            XCTAssert(eq(v.value, a))
            v.value = a
            XCTAssert(eq(v.value, a))
            v.value = b
            XCTAssert(eq(v.value, b))
            v.withTransaction {
                v.value = a
                v.value = c
            }
            XCTAssert(eq(v.value, c))
            v.value = a

            let mock = MockValueObserver(v, eq)
            mock.expecting(.init(from: a, to: b)) {
                v.value = b
            }
            XCTAssert(eq(v.value, b))
            mock.expecting(.init(from: b, to: c)) {
                v.withTransaction {
                    v.value = a
                    v.value = c
                }
            }
            XCTAssert(eq(v.value, c))
        }

        check(Variable<Int>(1), 1, 2, 3)
        check(IntVariable(1), 1, 2, 3)

        check(FloatVariable(1.0), 1.0, 2.0, 3.0)
        check(BoolVariable(false), false, true, false)
        check(StringVariable("foo"), "foo", "bar", "baz")
        check(Variable<Box>(Box(1)), Box(1), Box(2), Box(3))

        let box = Box(1)
        check(UnownedVariable<Box>(box), Box(1), Box(2), Box(3))
        check(WeakVariable<Box>(box), Box(1), Box(2), Box(3), ==)
    }

    func testUnownedVariable() {
        weak var box: Box? = nil
        let variable: UnownedVariable<Box>
        do {
            let b = Box(1)
            box = b
            variable = .init(b)
            XCTAssertEqual(box, Box(1))
            XCTAssertEqual(variable.value, Box(1))
            withExtendedLifetime(b) {}
        }
        XCTAssertNil(box, "An UnownedVariable must not retain its value")
        _ = variable // Accessing its value would trap here
    }

    func testWeakVariable() {
        weak var box: Box? = nil
        let variable: WeakVariable<Box>
        do {
            let b = Box(1)
            box = b
            variable = .init(b)
            XCTAssertEqual(box, Box(1))
            XCTAssertEqual(variable.value, Box(1))
            withExtendedLifetime(b) {}
        }
        XCTAssertNil(box)
        XCTAssertNil(variable.value)
    }


    func testLiteralExpressibility() {
        let int: IntVariable = 1
        XCTAssertEqual(int.value, 1)

        let float: FloatVariable = 2.0
        XCTAssertEqual(float.value, 2.0)

        let double: DoubleVariable = 2.0
        XCTAssertEqual(double.value, 2.0)

        let bool: BoolVariable = true
        XCTAssertEqual(bool.value, true)

        let string1: StringVariable = "foo"
        XCTAssertEqual(string1.value, "foo")

        let string2 = StringVariable(unicodeScalarLiteral: "bar") // ¯\_(ツ)_/¯
        XCTAssertEqual(string2.value, "bar")

        let string3 = StringVariable(extendedGraphemeClusterLiteral: "baz") // ¯\_(ツ)_/¯
        XCTAssertEqual(string3.value, "baz")

        let optional: OptionalVariable<Int> = nil
        XCTAssertEqual(optional.value, nil)
    }
}

private class Box: Equatable {
    var value: Int
    init(_ value: Int) { self.value = value }
    static func ==(a: Box, b: Box) -> Bool { return a.value == b.value }
}

