//
//  TransactionalTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

private class TransactionalTestObservable: ObservableValueType, TransactionalThing {
    typealias Value = Int
    typealias Change = ValueChange<Int>

    var _signal: TransactionalSignal<ValueChange<Int>>? = nil
    var _transactionCount: Int = 0

    var _value: Value = 0

    var value: Value {
        get { return _value }
        set {
            beginTransaction()
            let old = _value
            _value = newValue
            sendChange(.init(from: old, to: _value))
            endTransaction()
        }
    }

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        signal.add(sink)
    }

    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return signal.remove(sink)
    }

    var activated = 0
    var deactivated = 0

    func activate() {
        activated += 1
    }

    func deactivate() {
        deactivated += 1
    }
}

class TransactionalTests: XCTestCase {
    func testUpdatesSourceRemainsTheSame1() {
        let observable = TransactionalTestObservable()
        let sink1 = MockValueUpdateSink<Int>()
        let updates1 = observable.updates
        updates1.add(sink1)

        let sink2 = MockValueUpdateSink<Int>()
        let updates2 = observable.updates
        updates2.add(sink2)

        // We can't compare the sources, but we can check that triggering
        // a change is reported from both of them.

        sink1.expecting(["begin", "0 -> 1", "end"]) {
            sink2.expecting(["begin", "0 -> 1", "end"]) {
                observable.value = 1
            }
        }

        updates1.remove(sink1)
        updates2.remove(sink2)
    }

    func testUpdatesSourceRemainsTheSame2() {
        let observable = TransactionalTestObservable()
        let sink1 = MockValueUpdateSink<Int>()

        observable.updates.add(sink1)

        let sink2 = MockValueUpdateSink<Int>()
        observable.updates.add(sink2)

        // We can't compare the sources, but we can check that triggering
        // a change is reported from both of them.

        sink1.expecting(["begin", "0 -> 1", "end"]) {
            sink2.expecting(["begin", "0 -> 1", "end"]) {
                observable.value = 1
            }
        }
        observable.updates.remove(sink1)
        observable.updates.remove(sink2)
    }

    func testSendIfConnected() {
        let observable = TransactionalTestObservable()

        // The autoclosure argument should not be called if the observable isn't connected.
        observable.beginTransaction()
        observable.sendIfConnected({ XCTFail(); return ValueChange(from: 0, to: 1) }())
        observable.endTransaction()

        let sink = MockValueUpdateSink<Int>()
        observable.updates.add(sink)

        sink.expecting(["begin", "0 -> 1", "end"]) {
            observable.beginTransaction()
            observable.sendIfConnected(ValueChange(from: 0, to: 1))
            observable.endTransaction()
        }

        observable.updates.remove(sink)
    }

    func testSendLater() {
        let observable = TransactionalTestObservable()
        let sink = MockValueUpdateSink<Int>()

        observable.updates.add(sink)

        sink.expecting("begin") {
            observable.beginTransaction()
        }

        observable.signal.sendLater(.change(ValueChange(from: 0, to: 1)))

        sink.expecting("0 -> 1") {
            observable.signal.sendNow()
        }

        sink.expecting("end") {
            observable.endTransaction()
        }

        observable.updates.remove(sink)
    }

    func testSendUpdate() {
        let observable = TransactionalTestObservable()
        let sink = MockValueUpdateSink<Int>()

        observable.updates.add(sink)

        sink.expecting("begin") {
            observable.send(.beginTransaction)
        }

        sink.expecting("0 -> 1") {
            observable.send(.change(ValueChange(from: 0, to: 1)))
        }

        sink.expecting("end") {
            observable.send(.endTransaction)
        }

        observable.updates.remove(sink)
    }

    func testSubscribingToOpenTransaction() {
        let observable = TransactionalTestObservable()
        let sink = MockValueUpdateSink<Int>()

        observable.beginTransaction()

        sink.expecting("begin") {
            observable.updates.add(sink)
        }

        sink.expecting("end") {
            observable.endTransaction()
        }

        _ = observable.updates.remove(sink)
    }

    func testUnsubscribingFromOpenTransaction() {
        let observable = TransactionalTestObservable()
        let sink = MockValueUpdateSink<Int>()

        observable.updates.add(sink)

        sink.expecting("begin") {
            observable.beginTransaction()
        }
        sink.expecting("end") {
            _ = observable.updates.remove(sink)
        }

        observable.endTransaction()
    }

    func testPropertiesWithNestedTransactions() {
        let observable = TransactionalTestObservable()

        XCTAssertEqual(observable.isInTransaction, false)
        XCTAssertEqual(observable.isConnected, false)
        XCTAssertEqual(observable.isActive, false)

        // Start an outer transaction.
        observable.beginTransaction()

        XCTAssertEqual(observable.isInTransaction, true)
        XCTAssertEqual(observable.isConnected, false)
        XCTAssertEqual(observable.isActive, true)

        // Start a nested transaction.
        observable.beginTransaction()

        XCTAssertEqual(observable.isInTransaction, true)
        XCTAssertEqual(observable.isConnected, false)
        XCTAssertEqual(observable.isActive, true)

        observable.endTransaction()

        XCTAssertEqual(observable.isInTransaction, true)
        XCTAssertEqual(observable.isConnected, false)
        XCTAssertEqual(observable.isActive, true)

        observable.endTransaction()

        XCTAssertEqual(observable.isInTransaction, false)
        XCTAssertEqual(observable.isConnected, false)
        XCTAssertEqual(observable.isActive, false)

        let sink = MockValueUpdateSink<Int>()
        observable.updates.add(sink)

        XCTAssertEqual(observable.isInTransaction, false)
        XCTAssertEqual(observable.isConnected, true)
        XCTAssertEqual(observable.isActive, true)

        sink.expecting("begin") {
            observable.beginTransaction()
        }

        XCTAssertEqual(observable.isInTransaction, true)
        XCTAssertEqual(observable.isConnected, true)
        XCTAssertEqual(observable.isActive, true)

        sink.expecting("end") {
            observable.endTransaction()
        }

        XCTAssertEqual(observable.isInTransaction, false)
        XCTAssertEqual(observable.isConnected, true)
        XCTAssertEqual(observable.isActive, true)

        observable.updates.remove(sink)

        XCTAssertEqual(observable.isInTransaction, false)
        XCTAssertEqual(observable.isConnected, false)
        XCTAssertEqual(observable.isActive, false)
    }

    func testActivation() {
        let observable = TransactionalTestObservable()
        let sink = MockValueUpdateSink<Int>()

        XCTAssertEqual(observable.activated, 0)
        observable.updates.add(sink)
        XCTAssertEqual(observable.activated, 1)

        XCTAssertEqual(observable.deactivated, 0)
        observable.updates.remove(sink)
        XCTAssertEqual(observable.deactivated, 1)
    }
}

class TestTransactionalSource: TransactionalSource<ValueChange<Int>> {
    var activated = 0
    var deactivated = 0

    override func activate() {
        super.activate()
        activated += 1
    }

    override func deactivate() {
        super.deactivate()
        deactivated += 1
    }
}

class TransactionSourceTests: XCTestCase {
    func test() {
        let source = TestTransactionalSource()

        XCTAssertEqual(source.activated, 0)
        XCTAssertEqual(source.deactivated, 0)

        let sink = MockValueUpdateSink<Int>()
        source.add(sink)

        XCTAssertEqual(source.activated, 1)
        XCTAssertEqual(source.deactivated, 0)

        source.remove(sink)

        XCTAssertEqual(source.activated, 1)
        XCTAssertEqual(source.deactivated, 1)
    }
}

