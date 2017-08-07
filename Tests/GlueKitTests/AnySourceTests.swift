//
//  AnySourceTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-25.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

private class ForwardingSource<Source: SourceType>: SourceType {
    typealias Value = Source.Value

    let target: Source

    init(_ target: Source) {
        self.target = target
    }

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        target.add(sink)
    }

    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
        return target.remove(sink)
    }
}

class AnySourceTests: XCTestCase {
    func test_Works() {
        let signal = Signal<Int>()
        let source = signal.anySource

        let sink = MockSink<Int>()

        source.add(sink)

        sink.expecting(1) {
            signal.send(1)
        }

        source.remove(sink)

        sink.expectingNothing {
            signal.send(2)
        }
    }

    func test_Idempotent() {
        let signal = Signal<Int>()
        let source = signal.anySource.anySource

        let sink = MockSink<Int>()

        source.add(sink)

        sink.expecting(1) {
            signal.send(1)
        }

        source.remove(sink)

        sink.expectingNothing {
            signal.send(2)
        }
    }

    func test_Custom() {
        let signal = Signal<Int>()
        let source = ForwardingSource(signal).anySource

        let sink = MockSink<Int>()

        source.add(sink)

        sink.expecting(1) {
            signal.send(1)
        }

        source.remove(sink)

        sink.expectingNothing {
            signal.send(2)
        }
    }


    func test_RetainsOriginal() {
        weak var signal: Signal<Int>? = nil
        var source: AnySource<Int>? = nil

        do {
            let s = Signal<Int>()
            signal = s
            source = s.anySource
            withExtendedLifetime(s) {}
        }

        XCTAssertNotNil(signal)
        XCTAssertNotNil(source)
        source = nil
        XCTAssertNil(signal)
    }
}
