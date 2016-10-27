//
//  ObservableValueTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-08.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

class ObservableValueTests: XCTestCase {
    func test_anyObservable_fromObservableValue() {
        let test = TestObservableValue(0)

        let any = test.anyObservable

        XCTAssertEqual(any.value, 0)

        let updateSink = MockValueUpdateSink<Int>()
        any.updates.add(updateSink)

        let changeSink = TransformedMockSink<ValueChange<Int>, String>({ "\($0.old)→\($0.new)" })
        any.changes.add(changeSink)

        let valuesSink = MockSink<Int>()
        valuesSink.expecting(0) {
            any.values.add(valuesSink)
        }

        let futureValuesSink = MockSink<Int>()
        any.futureValues.add(futureValuesSink)

        updateSink.expecting("begin") {
            test.begin()
        }
        updateSink.expecting("0→1") {
            test.value = 1
        }

        updateSink.expecting("end") {
            changeSink.expecting("0→1") {
                valuesSink.expecting(1) {
                    futureValuesSink.expecting(1) {
                        test.end()
                    }
                }
            }
        }
    }

    func test_anyObservable_fromClosures() {
        var value = 0
        let signal = Signal<ValueUpdate<Int>>()
        let test = AnyObservableValue(getter: { value },
                                      updates: { signal.anySource })

        let any = test.anyObservable

        XCTAssertEqual(any.value, 0)

        let updateSink = MockValueUpdateSink<Int>()
        any.updates.add(updateSink)

        let changeSink = TransformedMockSink<ValueChange<Int>, String>({ "\($0.old)→\($0.new)" })
        any.changes.add(changeSink)

        let valuesSink = MockSink<Int>()
        valuesSink.expecting(0) {
            any.values.add(valuesSink)
        }

        let futureValuesSink = MockSink<Int>()
        any.futureValues.add(futureValuesSink)

        updateSink.expecting("begin") {
            signal.send(.beginTransaction)
        }
        updateSink.expecting("0→1") {
            value = 1
            signal.send(.change(ValueChange(from: 0, to: 1)))
        }

        updateSink.expecting("end") {
            changeSink.expecting("0→1") {
                valuesSink.expecting(1) {
                    futureValuesSink.expecting(1) {
                        signal.send(.endTransaction)
                    }
                }
            }
        }
    }

    func testObservableValueType_values_SendsInitialValue() {
        let test = TestObservableValue(0)

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
        let test = TestObservableValue(0)
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

        let sink = MockValueUpdateSink<Int>()
        constant.updates.add(sink)

        let sink2 = MockValueUpdateSink<Int>()
        let removed = constant.updates.remove(sink2)
        XCTAssert(removed.opened(as: TransformedMockSink<ValueUpdate<Int>, String>.self) === sink2)
    }
}
