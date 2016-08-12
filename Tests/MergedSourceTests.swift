//
//  MergedSourceTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-04.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

class MergedSourceTests: XCTestCase {

    func testSimpleMerge() {
        let s1 = Signal<Int>()
        let s2 = Signal<Int>()

        let source = s1.merged(with: s2)

        var r = [Int]()
        let c = source.connect { r.append($0) }

        s1.send(11)
        s2.send(21)
        s1.send(12)
        s1.send(13)
        s2.send(22)
        s2.send(23)

        XCTAssertEqual(r, [11, 21, 12, 13, 22, 23])

        c.disconnect()
    }

    func testNaryMerge() {
        var signals: [Signal<Int>] = []
        (0..<10).forEach { _ in signals.append(Signal<Int>()) }

        let merge = Signal.merge(signals)

        var r = [Int]()
        let c = merge.connect { i in r.append(i) }

        for i in 0..<20 {
            signals[i % signals.count].send(i)
        }

        c.disconnect()

        XCTAssertEqual(r, Array(0..<20))
    }

    func testReentrantMerge() {
        let s1 = Signal<Int>()
        let s2 = Signal<Int>()

        let source = s1.merged(with: s2)

        var s = ""
        let c = source.connect { i in
            s += " (\(i)"
            if i > 0 {
                s2.send(i - 1)
            }
            s += ")"
        }

        s1.send(3)

        XCTAssertEqual(s, " (3) (2) (1) (0)")
        c.disconnect()
    }

    func testMergeChaining() {
        let s1 = Signal<Int>()
        let s2 = Signal<Int>()
        let s3 = Signal<Int>()
        let s4 = Signal<Int>()

        // This does not chain three merged sources together; it creates a single merged source containing all sources.
        let merge = s1.merged(with: s2).merged(with: s3).merged(with: s4)

        var r = [Int]()
        let c = merge.connect { i in r.append(i) }

        s1.send(1)
        s2.send(2)
        s3.send(3)
        s4.send(4)

        XCTAssertEqual(r, [1, 2, 3, 4])
        c.disconnect()
    }

    
}
