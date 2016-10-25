//
//  AnySourceTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-25.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

private class ForwardingSource<Source: SourceType>: SourceType {
    typealias Value = Source.Value

    let target: Source

    init(_ target: Source) {
        self.target = target
    }

    @discardableResult
    func add<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Value {
        return target.add(sink)
    }

    @discardableResult
    func remove<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Value {
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
