//
//  ArrayBufferingTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-11-02.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

class ArrayBufferingTests: XCTestCase {
    func test_connectsImmediately() {
        let observable = TestObservableArray([1, 2, 3])

        do {
            let buffered = observable.buffered()
            XCTAssertTrue(observable.isConnected)
            withExtendedLifetime(buffered) {}
        }
        XCTAssertFalse(observable.isConnected)
    }

    func test_properties() {
        let observable = TestObservableArray([1, 2, 3])
        let buffered = observable.buffered()

        for b in [buffered, buffered.buffered()] {
            XCTAssertEqual(b.isBuffered, true)
            XCTAssertEqual(b[0], 1)
            XCTAssertEqual(b[1], 2)
            XCTAssertEqual(b[2], 3)
            XCTAssertEqual(b[0 ..< 2], [1, 2])
            XCTAssertEqual(b.value, [1, 2, 3])
            XCTAssertEqual(b.count, 3)
        }

        observable.apply(ArrayChange(initialCount: 3, modification: .replace(2, at: 1, with: 4)))
        XCTAssertEqual(buffered.value, [1, 4, 3])
    }

    func test_updates() {
        let observable = TestObservableArray([1, 2, 3])
        let buffered = observable.buffered()

        let sink = MockArrayObserver(buffered)

        sink.expecting(["begin", "3.remove(3, at: 2)", "end"]) {
            observable.apply(ArrayChange(initialCount: 3, modification: .remove(3, at: 2)))
        }
        XCTAssertEqual(buffered.value, [1, 2])

        sink.expecting("begin") {
            observable.beginTransaction()
        }

        sink.expectingNothing {
            observable.apply(ArrayChange(initialCount: 2, modification: .replace(1, at: 0, with: 2)))
        }
        XCTAssertEqual(buffered.value, [1, 2])

        sink.expectingNothing {
            observable.apply(ArrayChange(initialCount: 2, modification: .insert(6, at: 2)))
        }
        XCTAssertEqual(buffered.value, [1, 2])

        sink.expecting(["2.replace(1, at: 0, with: 2).insert(6, at: 2)", "end"]) {
            observable.endTransaction()
        }
        XCTAssertEqual(buffered.value, [2, 2, 6])

        sink.disconnect()
    }
}
