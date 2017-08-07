//
//  ArrayReferenceTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-11-02.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class ArrayReferenceTests: XCTestCase {
    func testReference() {
        let a: ArrayVariable<Int> = [1, 2, 3]
        let b: ArrayVariable<Int> = [10, 20]
        let c: ArrayVariable<Int> = []
        let ref = Variable<ArrayVariable<Int>>(a)

        XCTAssertEqual(ref.value.value, [1, 2, 3])
        a[1] = 4
        XCTAssertEqual(ref.value.value, [1, 4, 3])

        let unpacked = ref.unpacked()

        XCTAssertEqual(unpacked.isBuffered, false)
        XCTAssertEqual(unpacked.count, 3)
        XCTAssertEqual(unpacked[0], 1)
        XCTAssertEqual(Array(unpacked[0 ..< 3]), [1, 4, 3])
        XCTAssertEqual(unpacked.value, [1, 4, 3])
        a[0] = 2
        XCTAssertEqual(unpacked.value, [2, 4, 3])

        let sink = MockArrayObserver(unpacked)

        sink.expecting(["begin", "3.replace(3, at: 2, with: 6)", "end"]) {
            a[2] = 6
        }

        sink.expecting(["begin", "3.replaceSlice([2, 4, 6], at: 0, with: [10, 20])", "end"]) {
            ref.value = b
        }

        sink.expecting("begin") {
            b.apply(.beginTransaction)
        }

        sink.expectingNothing {
            ref.apply(.beginTransaction)
        }

        sink.expecting("2.insert(15, at: 1)") {
            b.insert(15, at: 1)
        }

        sink.expecting("3.replaceSlice([10, 15, 20], at: 0, with: [])") {
            ref.value = c
        }

        sink.expecting("0.insert(100, at: 0)") {
            c.append(100)
        }

        sink.expectingNothing {
            b.apply(.endTransaction)
        }

        sink.expecting("end") {
            ref.apply(.endTransaction)
        }
        
        sink.disconnect()

    }
}
