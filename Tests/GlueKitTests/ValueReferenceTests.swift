//
//  ValueReferenceTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-11-02.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class ValueReferenceTests: XCTestCase {
    func testReference() {
        let a = Variable<Int>(0)
        let b = Variable<Int>(10)
        let c = Variable<Int>(20)
        let ref = Variable<AnyObservableValue<Int>>(a.anyObservableValue)

        XCTAssertEqual(ref.value.value, 0)
        a.value = 1
        XCTAssertEqual(ref.value.value, 1)

        let unpacked = ref.unpacked()

        XCTAssertEqual(unpacked.value, 1)
        a.value = 2
        XCTAssertEqual(unpacked.value, 2)

        let sink = MockValueUpdateSink(unpacked)

        sink.expecting(["begin", "2 -> 3", "end"]) {
            a.value = 3
        }

        sink.expecting(["begin", "3 -> 10", "end"]) {
            ref.value = b.anyObservableValue
        }

        sink.expecting(["begin", "10 -> 11", "end"]) {
            b.value = 11
        }

        sink.expecting("begin") {
            b.apply(.beginTransaction)
        }

        sink.expectingNothing {
            ref.apply(.beginTransaction)
        }

        sink.expecting("11 -> 12") {
            b.value = 12
        }

        sink.expecting("12 -> 20") {
            ref.value = c.anyObservableValue
        }

        sink.expecting("20 -> 21") {
            c.value = 21
        }

        sink.expectingNothing {
            b.apply(.endTransaction)
        }

        sink.expecting("end") {
            ref.apply(.endTransaction)
        }

        sink.disconnect()
    }

    func testDerivedObservable() {
        let a = Variable<Int>(0)
        let double = a.map { 2 * $0 }

        let ref = Variable<AnyObservableValue<Int>>(a.anyObservableValue)

        let sink = MockValueUpdateSink(ref.unpacked())

        sink.expecting(["begin", "0 -> 1", "end"]) {
            a.value = 1
        }

        sink.expecting(["begin", "1 -> 2", "end"]) {
            ref.value = double.anyObservableValue
        }

        sink.expecting(["begin", "2 -> 4", "end"]) {
            a.value = 2
        }

        sink.disconnect()
    }
}
