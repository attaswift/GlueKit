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

        let buffered = observable.buffered()

        XCTAssertTrue(observable.isConnected)

        withExtendedLifetime(buffered) {}
    }

    func foo(_ observable: TestObservableValue<Int>, _ weakSink: inout MockSink<Int>?) {
    }

    func test_isntRetainedByObservable() {
        let observable = TestObservableValue(0)
        weak var weakSink: MockValueUpdateSink<Int>? = nil
        do {
            let buffered = observable.buffered()
            let sink = MockValueUpdateSink<Int>()
            weakSink = sink
            sink.connect(to: buffered.updates)
            withExtendedLifetime(buffered) {}
        }
        // If the sink is still alive, the buffered observable wasn't deallocated.
        XCTAssertNil(weakSink, "Possible retain cycle")
    }
}
