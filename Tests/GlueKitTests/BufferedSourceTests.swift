//
//  BufferedSourceTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

private class TestSource: SourceType {
    typealias Value = Int

    var added = 0
    var removed = 0
    var sinks: Set<AnySink<Int>> = []

    init() {}

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Int {
        added += 1
        let (inserted, _) = sinks.insert(sink.anySink)
        precondition(inserted)
    }

    @discardableResult
    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Int {
        removed += 1
        let old = sinks.remove(sink.anySink)!
        return old.opened()!
    }

    func send(_ value: Int) {
        for sink in sinks {
            if sinks.contains(sink) {
                sink.receive(value)
            }
        }
    }
}

class BufferedSourceTests: XCTestCase {
    func testRetainsInput() {
        weak var weakSource: TestSource? = nil
        var buffered: AnySource<Int>? = nil
        do {
            let source = TestSource()
            weakSource = source
            buffered = source.buffered()
        }

        XCTAssertNotNil(weakSource)
        XCTAssertNotNil(buffered)

        buffered = nil

        XCTAssertNil(weakSource)
    }

    func testSubscribesOnceWhileActive() {
        let source = TestSource()
        let buffered = source.buffered()

        XCTAssertEqual(source.added, 0)
        XCTAssertEqual(source.removed, 0)

        let sink = MockSink<Int>()
        buffered.add(sink)

        XCTAssertEqual(source.added, 1)
        XCTAssertEqual(source.removed, 0)

        let sink2 = MockSink<Int>()
        buffered.add(sink2)

        XCTAssertEqual(source.added, 1)
        XCTAssertEqual(source.removed, 0)

        buffered.remove(sink)

        XCTAssertEqual(source.added, 1)
        XCTAssertEqual(source.removed, 0)

        buffered.remove(sink2)

        XCTAssertEqual(source.added, 1)
        XCTAssertEqual(source.removed, 1)

        withExtendedLifetime(buffered) {}
    }

    func testReceivesValuesFromSource() {
        let source = TestSource()
        let buffered = source.buffered()

        let sink = MockSink<Int>()
        buffered.add(sink)

        sink.expecting(1) {
            source.send(1)
        }

        let sink2 = MockSink<Int>()
        buffered.add(sink2)

        sink.expecting(2) {
            sink2.expecting(2) {
                source.send(2)
            }
        }

        buffered.remove(sink)

        sink2.expecting(3) {
            source.send(3)
        }

        buffered.remove(sink2)

        sink.expectingNothing {
            sink2.expectingNothing {
                source.send(4)
            }
        }
    }
}
