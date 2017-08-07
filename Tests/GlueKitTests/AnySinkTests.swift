//
//  AnySinkTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-25.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

private class TestSink: SinkType {
    typealias Value = Int

    func receive(_ value: Value) {
        // Noop
    }
}

class AnySinkTests: XCTestCase {
    func test_equality() {
        let sink1 = MockSink<Int>()
        let sink2 = MockSink<Int>()
        let sink3 = TestSink()
        let sink4 = TestSink()

        XCTAssertEqual(sink1, sink1)
        XCTAssertNotEqual(sink1, sink2)
        XCTAssertNotEqual(sink3, sink4)

        XCTAssertEqual(sink1.anySink, sink1.anySink)
        XCTAssertNotEqual(sink1.anySink, sink2.anySink)
        XCTAssertNotEqual(sink1.anySink, sink3.anySink)

        XCTAssertEqual(sink1.anySink, sink1.anySink.anySink)
    }

    func test_hashValue() {
        let sink = MockSink<Int>()

        XCTAssertEqual(sink.hashValue, sink.anySink.hashValue)
    }

    func test_receive() {
        let sink = MockSink<Int>()

        sink.expecting(1) {
            sink.receive(1)
        }

        sink.expecting(2) {
            sink.anySink.receive(2)
        }

        sink.expecting(3) {
            sink.anySink.anySink.receive(3)
        }

    }
}
