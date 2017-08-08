//
//  UpdatableValueTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-27.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

class UpdatableValueTests: XCTestCase {
    func test_anyUpdatable_fromUpdatableValue() {
        let test = TestUpdatableValue<Int>(0)

        let any = test.anyUpdatableValue

        XCTAssertEqual(any.value, 0)

        let updateSink = MockValueUpdateSink<Int>(any.updates)

        let changeSink = TransformedMockSink<ValueChange<Int>, String>({ "\($0.old) -> \($0.new)" })
        changeSink.subscribe(to: any.changes)

        let valuesSink = MockSink<Int>()
        valuesSink.expecting(0) {
            valuesSink.subscribe(to: any.values)
        }

        let futureValuesSink = MockSink<Int>(any.futureValues)

        updateSink.expecting("begin") {
            test.beginTransaction()
        }
        updateSink.expecting("0 -> 1") {
            test.value = 1
        }

        updateSink.expecting("end") {
            changeSink.expecting("0 -> 1") {
                valuesSink.expecting(1) {
                    futureValuesSink.expecting(1) {
                        test.endTransaction()
                    }
                }
            }
        }

        updateSink.expecting(["begin", "1 -> 2", "end"]) {
            changeSink.expecting("1 -> 2") {
                valuesSink.expecting(2) {
                    futureValuesSink.expecting(2) {
                        any.value = 2
                    }
                }
            }
        }

        updateSink.expecting(["begin", "end"]) {
            any.withTransaction {}
        }

        updateSink.expecting(["begin", "2 -> 3", "3 -> 4", "end"]) {
            changeSink.expecting("2 -> 4") {
                valuesSink.expecting(4) {
                    futureValuesSink.expecting(4) {
                        any.withTransaction {
                            any.value = 3
                            any.value = 4
                        }
                    }
                }
            }
        }
    }

    func test_anyUpdatable_fromClosures() {
        var value = 0
        let signal = Signal<ValueUpdate<Int>>()
        var transactions = 0
        let begin = {
            transactions += 1
            if transactions == 1 {
                signal.send(.beginTransaction)
            }
        }
        let end = {
            transactions -= 1
            if transactions == 0 {
                signal.send(.endTransaction)
            }
        }

        let test = AnyUpdatableValue(
            getter: { value },
            apply: { (update: ValueUpdate<Int>) -> Void in
                switch update {
                case .beginTransaction: begin()
                case .change(let change):
                    value = change.new
                    signal.send(update)
                case .endTransaction: end()
                }
            },
            updates: signal.anySource)

        let any = test.anyUpdatableValue

        XCTAssertEqual(any.value, 0)

        let updateSink = MockValueUpdateSink<Int>(any.updates)

        let changeSink = TransformedMockSink<ValueChange<Int>, String>({ "\($0.old) -> \($0.new)" })
        changeSink.subscribe(to: any.changes)

        let valuesSink = MockSink<Int>()
        valuesSink.expecting(0) {
            valuesSink.subscribe(to: any.values)
        }

        let futureValuesSink = MockSink<Int>(any.futureValues)

        updateSink.expecting("begin") {
            begin()
        }
        updateSink.expecting("0 -> 1") {
            test.value = 1
        }

        updateSink.expecting("end") {
            changeSink.expecting("0 -> 1") {
                valuesSink.expecting(1) {
                    futureValuesSink.expecting(1) {
                        end()
                    }
                }
            }
        }

        updateSink.expecting(["begin", "1 -> 2", "end"]) {
            changeSink.expecting("1 -> 2") {
                valuesSink.expecting(2) {
                    futureValuesSink.expecting(2) {
                        any.value = 2
                    }
                }
            }
        }

        updateSink.expecting(["begin", "end"]) {
            any.withTransaction {}
        }

        updateSink.expecting(["begin", "2 -> 3", "3 -> 4", "end"]) {
            changeSink.expecting("2 -> 4") {
                valuesSink.expecting(4) {
                    futureValuesSink.expecting(4) {
                        any.withTransaction {
                            any.value = 3
                            any.value = 4
                        }
                    }
                }
            }
        }
    }

    func test_anyObservable_fromAnyUpdatable() {
        let test = TestUpdatableValue<Int>(0)
        let any = test.anyUpdatableValue.anyObservableValue

        XCTAssertEqual(any.value, 0)

        let updateSink = MockValueUpdateSink<Int>(any.updates)

        updateSink.expecting("begin") {
            test.beginTransaction()
        }
        updateSink.expecting("0 -> 1") {
            test.value = 1
        }

        updateSink.expecting("end") {
            test.endTransaction()
        }
    }
}
