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
    func testDefaultSource() {
        let v = Variable<Int>(0)

        var r = [Int]()
        let c = v.connect { value in r.append(value) }

        XCTAssertEqual(r, [0], "The default source should trigger immediately with the current value of the variable")

        v.value = 1
        XCTAssertEqual(r, [0, 1])

        v.setValue(2)
        XCTAssertEqual(r, [0, 1, 2])

        v.sink(3)
        XCTAssertEqual(r, [0, 1, 2, 3])

        c.disconnect()
    }

    func testFutureSource() {
        let v = Variable<Int>(0)

        var r = [Int]()
        let c = v.futureSource.connect { value in r.append(value) }

        XCTAssertEqual(r, [], "The future source should not trigger with the current value of the variable")

        v.value = 1
        XCTAssertEqual(r, [1])

        v.setValue(2)
        XCTAssertEqual(r, [1, 2])

        v.sink(3)
        XCTAssertEqual(r, [1, 2, 3])

        c.disconnect()
    }

    func testDefaultEqualityTestOnDefaultSource() {
        let v = Variable<Int>(0)
        var r = [Int]()
        let c = v.connect { i in r.append(i) }

        v.value = 0
        v.value = 1
        v.value = 1
        v.value = 1
        v.value = 2

        XCTAssertEqual(r, [0, 1, 2])

        c.disconnect()
    }

    func testDefaultEqualityTestOnFutureSource() {
        let v = Variable<Int>(0)
        var r = [Int]()
        let c = v.futureSource.connect { i in r.append(i) }

        v.value = 0 // This will be not sent to the future source.
        v.value = 1
        v.value = 1
        v.value = 1
        v.value = 2

        XCTAssertEqual(r, [1, 2])
        c.disconnect()
    }

    func testCustomEqualityTest() {
        let v = Variable<Int>(0, equalityTest: { a, b in false })

        var defaultValues = [Int]()
        let defaultConnection = v.connect { i in defaultValues.append(i) }

        var futureValues = [Int]()
        let futureConnection = v.futureSource.connect { i in futureValues.append(i) }

        v.value = 0
        v.value = 1
        v.value = 1
        v.value = 1
        v.value = 2

        XCTAssertEqual(defaultValues, [0, 0, 1, 1, 1, 2])
        XCTAssertEqual(futureValues, [0, 1, 1, 1, 2])
        defaultConnection.disconnect()
        futureConnection.disconnect()
    }

    func testNestedUpdatesWithTheImmediateSource() {
        let v = Variable<Int>(3)

        var s = ""
        let c = v.connect { i in
            s += " (\(i)"
            if i > 0 {
                // This is OK as long as it doesn't lead to infinite updates.
                // The value is updated immediately, but the source is triggered later, at the end of the outermost update.
                v.value--
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
        let c = v.futureSource.connect { i in
            s += " (\(i)"
            if i > 0 {
                // This is OK as long as it doesn't lead to infinite updates.
                // The value is updated immediately, but the source is triggered later, at the end of the outermost update.
                v.value--
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


    func testOneWayBinding() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(100)

        let c = master.connect(slave)

        XCTAssertEqual(slave.value, 0)

        master.value = 1

        XCTAssertEqual(master.value, 1)
        XCTAssertEqual(slave.value, 1)

        slave.value = 200

        XCTAssertEqual(master.value, 1, "Connection should not be a two-way binding")
        XCTAssertEqual(slave.value, 200)

        master.value = 2

        XCTAssertEqual(master.value, 2)
        XCTAssertEqual(slave.value, 2)

        c.disconnect()

        master.value = 3

        XCTAssertEqual(master.value, 3)
        XCTAssertEqual(slave.value, 2)
    }

    func testTwoWayBinding() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(1)

        let c = master.bind(slave)

        XCTAssertEqual(master.value, 0, "Slave should get the value of master")
        XCTAssertEqual(slave.value, 0, "Slave should get the value of master")

        master.value = 1

        XCTAssertEqual(master.value, 1)
        XCTAssertEqual(slave.value, 1)

        slave.value = 2

        XCTAssertEqual(master.value, 2)
        XCTAssertEqual(slave.value, 2)

        c.disconnect() // The variables should now be independent again.

        master.value = 3

        XCTAssertEqual(master.value, 3)
        XCTAssertEqual(slave.value, 2)

        slave.value = 4

        XCTAssertEqual(master.value, 3)
        XCTAssertEqual(slave.value, 4)
    }

    func testReentrantSinks() {
        let v = Variable<Int>(0)

        var s = String()
        let c1 = v.connect { i in
            s += " (\(i)"
            if i > 0 {
                v.value = i - 1
            }
            s += ")"
        }
        let c2 = v.connect { i in
            s += " (\(i)"
            if i > 0 {
                v.value = i - 1
            }
            s += ")"
        }

        XCTAssertEqual(s, " (0) (0)")

        s = ""
        v.value = 2

        XCTAssertEqual(s, " (2) (2) (1) (1) (0) (0)")

        c1.disconnect()
        c2.disconnect()
    }
}
