//
//  DistinctTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-08.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

class DistinctTests: XCTestCase {
    func test_updates_reportsChangesAtTheEndOfTheTransaction() {
        let test = TestUpdatableValue(0)
        let distinct = test.distinct()

        let sink = MockValueUpdateSink<Int>()
        distinct.updates.add(sink)

        sink.expecting("begin") {
            test.beginTransaction()
        }

        sink.expectingNothing {
            test.value = 1
            test.value = 2
        }

        sink.expecting(["0 -> 2", "end"]) {
            test.endTransaction()
        }

        distinct.updates.remove(sink)
    }

    func test_updates_ignoresTransactionsThatDontChangeTheValue() {
        let test = TestUpdatableValue(0)
        let distinct = test.distinct()

        let sink = MockValueUpdateSink<Int>()
        distinct.updates.add(sink)

        sink.expecting("begin") {
            test.beginTransaction()
        }

        sink.expectingNothing {
            test.value = 1
            test.value = 0
        }

        sink.expecting(["end"]) {
            test.endTransaction()
        }

        distinct.updates.remove(sink)
    }

    func test_updates_subscribersMaySeeDifferentChanges() {
        let test = TestUpdatableValue(0)
        let distinct = test.distinct()

        let sink0to2 = MockValueUpdateSink<Int>()
        distinct.updates.add(sink0to2)

        let sink0to3 = MockValueUpdateSink<Int>()
        distinct.updates.add(sink0to3)

        sink0to2.expecting("begin") {
            sink0to3.expecting("begin") {
                test.beginTransaction()
            }
        }

        sink0to2.expectingNothing {
            sink0to3.expectingNothing {
                test.value = 1
            }
        }

        let sink1to2 = MockValueUpdateSink<Int>()
        sink1to2.expecting("begin") {
            distinct.updates.add(sink1to2)
        }

        let sink1to3 = MockValueUpdateSink<Int>()
        sink1to3.expecting("begin") {
            distinct.updates.add(sink1to3)
        }

        sink0to2.expectingNothing {
            sink0to3.expectingNothing {
                sink1to2.expectingNothing {
                    sink1to3.expectingNothing {
                        test.value = 2
                    }
                }
            }
        }

        sink0to2.expecting(["0 -> 2", "end"]) {
            distinct.updates.remove(sink0to2)
        }

        sink1to2.expecting(["1 -> 2", "end"]) {
            distinct.updates.remove(sink1to2)
        }

        sink0to3.expectingNothing {
            sink1to3.expectingNothing {
                test.value = 3
            }
        }

        sink0to3.expecting(["0 -> 3", "end"]) {
            sink1to3.expecting(["1 -> 3", "end"]) {
                test.endTransaction()
            }
        }

        sink0to3.expectingNothing {
            distinct.updates.remove(sink0to3)
        }

        sink1to3.expectingNothing {
            distinct.updates.remove(sink1to3)
        }
    }

    func test_values_defaultEqualityTest() {
        let test = TestObservableValue(0)
        let values = test.distinct().values

        let sink = MockSink<Int>()

        sink.expecting(0) {
            values.add(sink)
        }

        sink.expectingNothing {
            test.value = 0
        }

        sink.expecting(1) {
            test.value = 1
        }

        sink.expectingNothing {
            test.value = 1
            test.value = 1
        }

        sink.expecting(2) {
            test.value = 2
        }

        values.remove(sink)
    }

    func test_futureValues_defaultEqualityTest() {
        let test = TestObservableValue(0)
        let values = test.distinct().futureValues

        let sink = MockSink<Int>()

        sink.expectingNothing {
            values.add(sink)
            test.value = 0
        }

        sink.expecting(1) {
            test.value = 1
        }

        sink.expectingNothing {
            test.value = 1
            test.value = 1
        }

        sink.expecting(2) {
            test.value = 2
        }
        
        values.remove(sink)
    }

    func test_values_customEqualityTest() {
        let test = TestObservableValue(0)

        // This is a really stupid equality test: 1 is never equal to anything, while everything else is the same.
        // This will only let through changes from/to a 1 value.
        let distinct = test.distinct { a, b in a != 1 && b != 1 }
        let values = distinct.values

        let sink = MockSink<Int>()

        sink.expecting(0) {
            values.add(sink)
        }

        sink.expectingNothing {
            test.value = 0
        }

        sink.expecting(1) {
            test.value = 1
        }

        sink.expecting(1) {
            test.value = 1
        }

        sink.expecting(1) {
            test.value = 1
        }

        sink.expecting(2) {
            test.value = 2
        }

        sink.expectingNothing {
            test.value = 2
            test.value = 2
            test.value = 3
            test.value = 2
            test.value = 4
        }

        values.remove(sink)
    }

    func testDistinct_IsUpdatableWhenCalledOnUpdatables() {
        let test = TestUpdatableValue(0)

        let d = test.distinct()

        XCTAssertEqual(d.value, 0)

        let mock = MockValueUpdateSink(d)

        mock.expecting(["begin", "0 -> 42", "end"]) {
            d.value = 42
        }

        XCTAssertEqual(d.value, 42)
        XCTAssertEqual(test.value, 42)

        mock.expecting(["begin", "42 -> 23", "end"]) {
            d.withTransaction {
                d.value = 23
            }
        }

        mock.expecting(["begin", "end"]) {
            d.withTransaction {}
        }

        XCTAssertEqual(d.value, 23)
        XCTAssertEqual(test.value, 23)
    }
}

