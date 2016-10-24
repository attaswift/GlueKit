//
//  ObservableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-08.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

class ObservableTests: XCTestCase {
    func testObservableValueType_values_SendsInitialValue() {
        let test = TestObservable(0)

        var res = [Int]()

        let connection = test.values.connect { res.append($0) }
        XCTAssertEqual(res, [0])
        test.value = 1
        test.value = 2
        connection.disconnect()
        test.value = 3

        XCTAssertEqual(res, [0, 1, 2])
    }

    func testObservableValueType_values_SupportsNestedSendsBySerializingThem() {
        let test = TestObservable(0)
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

    func testObservableValueType_constant() {
        let constant = AnyObservableValue.constant(1)

        XCTAssertEqual(constant.value, 1)
    }
}
