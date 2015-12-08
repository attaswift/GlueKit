//
//  ObservableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-08.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

private struct TestObservable: ObservableType {
    var testValue: Int = 0
    var signal = Signal<SimpleChange<Int>>()

    var value: Int {
        get { return testValue }
        set {
            let change = SimpleChange(oldValue: testValue, newValue: newValue)
            testValue = newValue
            signal.send(change)
        }
    }
    var futureChanges: Source<SimpleChange<Int>> { return signal.source }
}

class ObservableTests: XCTestCase {
    func testSimpleChange_applyOn_SimplyReturnsTheNewValue() {
        let change = SimpleChange<Int>(oldValue: 1, newValue: 2)

        XCTAssertEqual(change.applyOn(0), 2)
    }

    func testObservableType_values_SendsInitialValue() {
        var test = TestObservable()

        var res = [Int]()

        let connection = test.values.connect { res.append($0) }
        XCTAssertEqual(res, [0])
        test.value = 1
        test.value = 2
        connection.disconnect()
        test.value = 3

        XCTAssertEqual(res, [0, 1, 2])
    }

    func testObservableType_values_SupportsNestedSendsBySerializingThem() {
        var test = TestObservable()
        var s = ""

        let c1 = test.values.connect { i in
            s += " (\(i)"
            if i > 0 {
                test.value = i - 1
            }
            s += ")"
        }
        let c2 = test.values.connect { i in
            s += " (\(i)"
            if i > 0 {
                test.value = i - 1
            }
            s += ")"
        }
        XCTAssertEqual(s, " (0) (0)")

        s = ""
        test.value = 2
        XCTAssertEqual(s, " (2) (2) (1) (1) (1) (1) (0) (0) (0) (0) (0) (0) (0) (0)")

        c1.disconnect()
        c2.disconnect()
    }
}
