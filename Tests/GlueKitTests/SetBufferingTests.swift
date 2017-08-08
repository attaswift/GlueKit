//
//  SetBufferingTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-11-02.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

class SetBufferingTests: XCTestCase {
    func test_connectsImmediately() {
        let observable = TestObservableSet([1, 2, 3])

        do {
            let buffered = observable.buffered()
            XCTAssertTrue(observable.isConnected)
            withExtendedLifetime(buffered) {}
        }
        XCTAssertFalse(observable.isConnected)
    }

    func test_properties() {
        let observable = TestObservableSet([1, 2, 3])
        let buffered = observable.buffered()

        for b in [buffered, buffered.buffered()] {
            XCTAssertEqual(b.isBuffered, true)
            XCTAssertEqual(b.count, 3)
            XCTAssertEqual(b.value, [1, 2, 3])
            XCTAssertEqual(b.contains(0), false)
            XCTAssertEqual(b.contains(1), true)
            XCTAssertEqual(b.isSubset(of: [1, 2, 3, 4]), true)
            XCTAssertEqual(b.isSubset(of: [2, 3, 4, 5]), false)
            XCTAssertEqual(b.isSuperset(of: [1, 2]), true)
            XCTAssertEqual(b.isSuperset(of: [3, 4]), false)
        }

        observable.apply(SetChange(removed: [3], inserted: [0]))
        XCTAssertEqual(buffered.value, [0, 1, 2])

    }

    func test_updates() {
        let observable = TestObservableSet([1, 2, 3])
        let buffered = observable.buffered()

        let sink = MockSetObserver(buffered)

        sink.expecting(["begin", "[3]/[]", "end"]) {
            observable.apply(SetChange(removed: [3]))
        }
        XCTAssertEqual(buffered.value, [1, 2])

        sink.expecting("begin") {
            observable.beginTransaction()
        }

        sink.expectingNothing {
            observable.apply(SetChange(removed: [2], inserted: [4]))
        }
        XCTAssertEqual(buffered.value, [1, 2])

        sink.expectingNothing {
            observable.apply(SetChange(inserted: [9]))
        }
        XCTAssertEqual(buffered.value, [1, 2])

        sink.expecting(["[2]/[4, 9]", "end"]) {
            observable.endTransaction()
        }
        XCTAssertEqual(buffered.value, [1, 4, 9])

        sink.disconnect()
    }
}
