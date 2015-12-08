//
//  UpdatableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

class UpdatableTests: XCTestCase {

    func testDefaultEqualityTestOnValuesSource() {
        let v = Variable<Int>(0).distinct()
        var r = [Int]()
        let c = v.values.connect { i in r.append(i) }

        v.value = 0
        v.value = 1
        v.value = 1
        v.value = 1
        v.value = 2

        XCTAssertEqual(r, [0, 1, 2])

        c.disconnect()
    }

    func testDefaultEqualityTestOnFutureValuesSource() {
        let v = Variable<Int>(0).distinct()
        var r = [Int]()
        let c = v.futureValues.connect { i in r.append(i) }

        v.value = 0 // This will be not sent to the future source.
        v.value = 1
        v.value = 1
        v.value = 1
        v.value = 2

        XCTAssertEqual(r, [1, 2])
        c.disconnect()
    }

    func testDefaultEqualityTestOnFutureChangesSource() {
        let v = Variable<Int>(0).distinct()
        var r = [String]()
        let c = v.futureChanges.connect { change in r.append("\(change.oldValue) to \(change.newValue)") }

        v.value = 0 // This will be not sent to the future source.
        v.value = 1
        v.value = 1
        v.value = 1
        v.value = 2

        XCTAssertEqual(r, ["0 to 1", "1 to 2"])
        c.disconnect()
    }

    func testCustomEqualityTest() {
        let v = Variable<Int>(0).distinct { a, b in false }

        var defaultValues = [Int]()
        let defaultConnection = v.values.connect { i in defaultValues.append(i) }

        var futureValues = [Int]()
        let futureConnection = v.futureValues.connect { i in futureValues.append(i) }

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


    func testOneWayBinding() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(100)

        let c = master.values.connect(slave)

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

        XCTAssertEqual(master.value, 0) // Slave should get the value of master
        XCTAssertEqual(slave.value, 0)

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

}
