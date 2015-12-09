//
//  SourceOperatorTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-03.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

class SourceOperatorTests: XCTestCase {

    func testSourceOperatorIsCalledOnEachSinkDuringEachSend() {
        let signal = Signal<Int>()

        var count = 0
        let source = signal.sourceOperator { (input: Int, sink: Sink<Double>) in
            count += 1
        }
        XCTAssertEqual(count, 0)

        let c1 = source.connect { _ in }
        let c2 = source.connect { _ in }
        XCTAssertEqual(count, 0)

        signal.send(10)
        XCTAssertEqual(count, 2)

        signal.send(20)
        XCTAssertEqual(count, 4)

        signal.send(30)
        XCTAssertEqual(count, 6)

        c1.disconnect()
        c2.disconnect()

        signal.send(40)
        XCTAssertEqual(count, 6)
    }

    func testSourceOperatorRetainsSource() {
        var source: Source<Int>? = nil
        weak var weakSignal: Signal<Int>? = nil
        do {
            let signal = Signal<Int>()
            weakSignal = signal

            source = signal.sourceOperator { (input: Int, sink: Sink<Int>) in
                // Noop
                sink.receive(input)
            }
        }

        XCTAssertNotNil(weakSignal)

        source = nil
        XCTAssertNil(weakSignal)

        noop(source)
    }

    func testSourceDoesntRetainOperator() {
        weak var weakResource: NSObject? = nil
        do {
            let resource = NSObject()
            weakResource = resource
            let source = Signal<Int>().sourceOperator { (input: Int, sink: Sink<Int>) in
                noop(resource)
                sink.receive(input)
            }
            XCTAssertNotNil(weakResource)
            noop(source)
        }

        XCTAssertNil(weakResource)
    }

    func testMap() {
        let signal = Signal<Int>()

        let source = signal.map { i in "\(i)" }

        var received = [String]()
        let connection = source.connect { received.append("\($0)") }

        signal.send(1)
        signal.send(2)
        signal.send(3)

        connection.disconnect()

        XCTAssertEqual(received, ["1", "2", "3"])
    }

    func testFilter() {
        let signal = Signal<Int>()
        let oddSource = signal.filter { $0 % 2 == 1 }

        var received = [Int]()
        let connection = oddSource.connect { received.append($0) }

        (1...10).forEach { signal.send($0) }

        connection.disconnect()

        XCTAssertEqual(received, [1, 3, 5, 7, 9])
    }

    func testOptionalFlatMap() {
        let signal = Signal<Int>()
        let source = signal.flatMap { i in i % 2 == 0 ? i / 2 : nil }

        var received = [Int]()
        let connection = source.connect { received.append($0) }

        (1...10).forEach { signal.send($0) }

        connection.disconnect()

        XCTAssertEqual(received, [1, 2, 3, 4, 5])
    }

    func testArrayFlatMap() {
        let signal = Signal<Int>()
        let source = signal.flatMap { (i: Int) -> [Int] in
            if i > 0 {
                return (1...i).filter { i % $0 == 0 }
            }
            else {
                return []
            }
        }
        // Source sends all divisors of all numbers sent by its input source.

        var received = [Int]()
        let connection = source.connect { received.append($0) }

        (1...10).forEach { signal.send($0) }

        connection.disconnect()

        XCTAssertEqual(received, [
            1,
            1, 2,
            1, 3,
            1, 2, 4,
            1, 5,
            1, 2, 3, 6,
            1, 7,
            1, 2, 4, 8,
            1, 3, 9,
            1, 2, 5, 10
        ])
    }

    func testEveryNth() {
        let signal = Signal<Int>()
        let source = signal.everyNth(3)

        var r1 = [Int]()
        let c1 = source.connect { r1.append($0) }

        signal.send(1)

        var r2 = [Int]()
        let c2 = source.connect { r2.append($0) }

        signal.send(2)

        var r3 = [Int]()
        let c3 = source.connect { r3.append($0) }

        (3...11).forEach(signal.send)

        c1.disconnect()
        c2.disconnect()
        c3.disconnect()

        // Each sink gets its own counter.
        
        XCTAssertEqual(r1, [3, 6, 9])
        XCTAssertEqual(r2, [4, 7, 10])
        XCTAssertEqual(r3, [5, 8, 11])
    }

    func testLatestOf() {
        let sa = Signal<Int>()
        let sb = Signal<String>()

        var r = [String]()

        let c = Signal.latestOf(sa, sb).connect { i, s in r.append("\(i), \(s)") }

        sa.send(1)
        sa.send(2)
        sb.send("foo")
        sb.send("bar")
        sa.send(3)
        sb.send("baz")

        c.disconnect()

        XCTAssertEqual(r, ["2, foo", "2, bar", "3, bar", "3, baz"])
    }
}
