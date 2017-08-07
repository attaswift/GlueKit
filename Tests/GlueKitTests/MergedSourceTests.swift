//
//  MergedSourceTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-04.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class MergedSourceTests: XCTestCase {

    func testSimpleMerge() {
        let s1 = Signal<Int>()
        let s2 = Signal<Int>()

        let source = s1.merged(with: s2)

        let sink = MockSink<Int>()
        source.add(sink)

        sink.expecting(11) { s1.send(11) }
        sink.expecting(21) { s2.send(21) }
        sink.expecting(12) { s1.send(12) }
        sink.expecting(13) { s1.send(13) }
        sink.expecting(22) { s2.send(22) }
        sink.expecting(23) { s2.send(23) }

        source.remove(sink)
    }

    func testNaryMerge() {
        var signals: [Signal<Int>] = []
        (0 ..< 10).forEach { _ in signals.append(Signal<Int>()) }

        let merge = Signal.merge(signals)

        let sink = MockSink<Int>()
        merge.add(sink)

        sink.expecting(Array(0 ..< 20)) {
            for i in 0 ..< 20 {
                signals[i % signals.count].send(i)
            }
        }
        merge.remove(sink)
    }

    func testReentrantMerge() {
        let s1 = Signal<Int>()
        let s2 = Signal<Int>()

        let source = s1.merged(with: s2)

        var s = ""
        let c = source.subscribe { i in
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

    func testVariadicMerge() {
        let s1 = Signal<Int>()
        let s2 = Signal<Int>()
        let s3 = Signal<Int>()
        let s4 = Signal<Int>()

        let merge = Signal.merge(s1, s2, s3, s4)

        let sink = MockSink<Int>()
        merge.add(sink)

        sink.expecting(1) { s1.send(1) }
        sink.expecting(2) { s1.send(2) }
        sink.expecting(3) { s1.send(3) }
        sink.expecting(4) { s1.send(4) }

        merge.remove(sink)
    }

    func testMergeChaining() {
        let s1 = Signal<Int>()
        let s2 = Signal<Int>()
        let s3 = Signal<Int>()
        let s4 = Signal<Int>()

        // This does not chain three merged sources together; it creates a single merged source containing all sources.
        let merge = s1.merged(with: s2).merged(with: s3).merged(with: s4)

        let sink = MockSink<Int>()
        merge.add(sink)

        sink.expecting(1) { s1.send(1) }
        sink.expecting(2) { s1.send(2) }
        sink.expecting(3) { s1.send(3) }
        sink.expecting(4) { s1.send(4) }

        merge.remove(sink)
    }
}
