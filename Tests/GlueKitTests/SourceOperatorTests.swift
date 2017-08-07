//
//  SourceOperatorTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-03.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class SourceOperatorTests: XCTestCase {

    func testSourceOperatorIsCalledOnEachSinkDuringEachSend() {
        let signal = Signal<Int>()

        var count = 0
        let source = signal.transform(Double.self) { input, sink in
            count += 1
        }
        XCTAssertEqual(count, 0)

        let c1 = source.subscribe { _ in }
        let c2 = source.subscribe { _ in }
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
        var source: AnySource<Int>? = nil
        weak var weakSignal: Signal<Int>? = nil
        do {
            let signal = Signal<Int>()
            weakSignal = signal

            source = signal.transform(Int.self) { input, sink in
                // Noop
                sink(input)
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
            let source = Signal<Int>().transform(Int.self) { input, sink in
                noop(resource)
                sink(input)
            }
            XCTAssertNotNil(weakResource)
            noop(source)
        }

        XCTAssertNil(weakResource)
    }

    func testMap() {
        let signal = Signal<Int>()

        let source = signal.map { i in "\(i)" }

        let sink = MockSink<String>()
        source.add(sink)

        sink.expecting("1") { signal.send(1) }
        sink.expecting("2") { signal.send(2) }
        sink.expecting("3") { signal.send(3) }

        source.remove(sink)
    }

    func testFilter() {
        let signal = Signal<Int>()
        let oddSource = signal.filter { $0 % 2 == 1 }

        let sink = MockSink<Int>()
        oddSource.add(sink)

        sink.expecting([1, 3, 5, 7, 9]) {
            (1...10).forEach { signal.send($0) }
        }

        oddSource.remove(sink)
    }

    func testOptionalFlatMap() {
        let signal = Signal<Int>()
        let source = signal.flatMap { i in i % 2 == 0 ? i / 2 : nil }

        let sink = MockSink<Int>()
        source.add(sink)
        sink.expecting([1, 2, 3, 4, 5]) {
            (1...10).forEach { signal.send($0) }
        }
        source.remove(sink)
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

        let sink = MockSink<Int>()
        source.add(sink)

        sink.expecting(1) { signal.send(1) }
        sink.expecting([1, 2]) { signal.send(2) }
        sink.expecting([1, 3]) { signal.send(3) }
        sink.expecting([1, 2, 4]) { signal.send(4) }
        sink.expecting([1, 5]) { signal.send(5) }
        sink.expecting([1, 2, 3, 6]) { signal.send(6) }
        sink.expecting([1, 7]) { signal.send(7) }
        sink.expecting([1, 2, 4, 8]) { signal.send(8) }
        sink.expecting([1, 3, 9]) { signal.send(9) }
        sink.expecting([1, 2, 5, 10]) { signal.send(10) }

        source.remove(sink)
    }
}
