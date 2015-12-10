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
    #if false
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
    #endif

    func testValuesSource() {
        let v = Variable<Int>(0)

        var r = [Int]()
        let c = v.values.connect { value in r.append(value) }

        XCTAssertEqual(r, [0], "The values source should trigger immediately with the current value of the variable")

        v.value = 1
        XCTAssertEqual(r, [0, 1])

        v.setValue(2)
        XCTAssertEqual(r, [0, 1, 2])

        v.setValue(2)
        XCTAssertEqual(r, [0, 1, 2, 2])

        v.sink.receive(3)
        XCTAssertEqual(r, [0, 1, 2, 2, 3])
        
        c.disconnect()
    }

    func testFutureValuesSource() {
        let v = Variable<Int>(0)

        var r = [Int]()
        let c = v.futureValues.connect { value in r.append(value) }

        XCTAssertEqual(r, [], "The future values source should not trigger with the current value of the variable")

        v.value = 1
        XCTAssertEqual(r, [1])

        v.setValue(2)
        XCTAssertEqual(r, [1, 2])

        v.setValue(2)
        XCTAssertEqual(r, [1, 2, 2])

        v.sink.receive(3)
        XCTAssertEqual(r, [1, 2, 2, 3])

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
        let c = v.futureValues.connect { i in
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
}
