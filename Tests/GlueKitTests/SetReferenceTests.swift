//
//  SetReferenceTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-11-02.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class SetReferenceTests: XCTestCase {
    func testReference() {
        let a: SetVariable<Int> = [1, 2, 3]
        let b: SetVariable<Int> = [10, 20]
        let c: SetVariable<Int> = [7]
        let ref = Variable<SetVariable<Int>>(a)

        XCTAssertEqual(ref.value.value, Set([1, 2, 3]))
        a.insert(4)
        XCTAssertEqual(ref.value.value, Set([1, 2, 3, 4]))

        let unpacked = ref.unpacked()

        XCTAssertEqual(unpacked.isBuffered, false)
        XCTAssertEqual(unpacked.count, 4)
        XCTAssertEqual(unpacked.value, Set([1, 2, 3, 4]))
        XCTAssertEqual(unpacked.contains(0), false)
        XCTAssertEqual(unpacked.contains(1), true)
        XCTAssertEqual(unpacked.isSubset(of: [1, 2, 3, 4, 5]), true)
        XCTAssertEqual(unpacked.isSubset(of: [2, 3, 4, 5, 6]), false)
        XCTAssertEqual(unpacked.isSuperset(of: [1, 2, 3]), true)
        XCTAssertEqual(unpacked.isSuperset(of: [3, 4, 5]), false)

        a.remove(2)
        XCTAssertEqual(unpacked.value, [1, 3, 4])

        let sink = MockSetObserver(unpacked)

        sink.expecting(["begin", "[1]/[]", "end"]) {
            a.remove(1)
        }

        sink.expecting(["begin", "[3, 4]/[10, 20]", "end"]) {
            ref.value = b
        }

        sink.expecting("begin") {
            b.apply(.beginTransaction)
        }

        sink.expectingNothing {
            ref.apply(.beginTransaction)
        }

        sink.expecting("[]/[15]") {
            b.insert(15)
        }

        sink.expecting("[10, 15, 20]/[7]") {
            ref.value = c
        }
        
        sink.expecting("[]/[8]") {
            c.insert(8)
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
