//
//  BufferedValueTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-28.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

class BufferedValueTests: XCTestCase {

    func test_connectsImmediately() {
        let observable = TestObservableValue(0)

        do {
            let buffered = observable.buffered()
            XCTAssertTrue(observable.isConnected)
            withExtendedLifetime(buffered) {}
        }
        XCTAssertFalse(observable.isConnected)
    }

    func test_isntRetainedByObservable() {
        let observable = TestObservableValue(0)
        weak var weakSink: MockValueUpdateSink<Int>? = nil
        do {
            let buffered = observable.buffered()
            let sink = MockValueUpdateSink<Int>()
            weakSink = sink
            sink.subscribe(to: buffered.updates)
            withExtendedLifetime(buffered) {}
        }
        // If the sink is still alive, the buffered observable wasn't deallocated.
        XCTAssertNil(weakSink, "Possible retain cycle")
    }

    func test_updates() {
        let observable = TestObservableValue(0)
        let buffered = observable.buffered()

        XCTAssertEqual(buffered.value, 0)
        observable.value = 1
        XCTAssertEqual(buffered.value, 1)

        let sink = MockValueUpdateSink(buffered)

        sink.expecting(["begin", "1 -> 2", "end"]) {
            observable.value = 2
        }

        sink.expecting("begin") {
            observable.begin()
        }

        sink.expectingNothing {
            observable.value = 3
        }

        sink.expectingNothing {
            observable.value = 4
        }

        sink.expecting(["2 -> 4", "end"]) {
            observable.end()
        }

        sink.disconnect()
    }
}
