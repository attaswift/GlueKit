//
//  ChangesSourceTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

class ChangesSourceTests: XCTestCase {
    func testRetainsObservable() {
        weak var weakObservable: TestObservable? = nil
        var changes: AnySource<TestChange>? = nil
        do {
            let observable = TestObservable(0)
            weakObservable = observable
            changes = observable.changes
        }
        XCTAssertNotNil(changes)
        XCTAssertNotNil(weakObservable)
        changes = nil
        XCTAssertNil(weakObservable)
    }

    func testSubscribingToChangesSubscribesToUpdates() {
        let observable = TestObservable(0)
        let changes = observable.changes

        let sink = MockSink<TestChange>()

        XCTAssertFalse(observable.isConnected)

        changes.add(sink)

        XCTAssertTrue(observable.isConnected)

        changes.remove(sink)

        XCTAssertFalse(observable.isConnected)
    }

    func testChangesSendsCompletedChanges() {
        let observable = TestObservable(0)
        let changes = observable.changes

        let sink = MockSink<TestChange>()

        changes.add(sink)

        sink.expectingNothing {
            observable.beginTransaction()
            observable.value = 1
            observable.value = 2
        }

        sink.expecting(TestChange([0, 1, 2])) {
            observable.endTransaction()
        }

        changes.remove(sink)
    }

    func testRemovingASinkDuringATransactionSendsPartialChanges() {
        let observable = TestObservable(0)
        let changes = observable.changes

        let sink = MockSink<TestChange>()
        changes.add(sink)
        observable.beginTransaction()
        observable.value = 1
        observable.value = 2
        sink.expecting(TestChange([0, 1, 2])) {
            _ = changes.remove(sink)
        }
        observable.value = 3
        observable.endTransaction()
    }

    func testDifferentSinksMayReceiveDifferentChanges() {
        let observable = TestObservable(0)
        let changes = observable.changes

        let sink1 = MockSink<TestChange>()
        changes.add(sink1)

        observable.beginTransaction()
        observable.value = 1

        let sink2 = MockSink<TestChange>()
        changes.add(sink2)

        observable.value = 2

        sink1.expecting(TestChange([0, 1, 2])) {
            _ = changes.remove(sink1)
        }

        observable.value = 3

        sink2.expecting(TestChange([1, 2, 3])) {
            observable.endTransaction()
        }

        changes.remove(sink2)
    }
}
