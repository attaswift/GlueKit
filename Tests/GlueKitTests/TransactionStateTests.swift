//
//  TransactionStateTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import GlueKit

private class TransactionTestObservable: ObservableValueType, SignalDelegate {
    typealias Value = Int
    typealias Change = ValueChange<Int>

    var state = TransactionState<Change>()

    var _value: Value = 0

    var value: Value {
        get { return _value }
        set {
            state.begin()
            let old = _value
            _value = newValue
            state.send(.init(from: old, to: _value))
            state.end()
        }
    }

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        state.add(sink, with: self)
    }
    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return state.remove(sink)
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

class TransactionStateTests: XCTestCase {
    func testUpdatesSourceRemainsTheSame1() {
        let observable = TransactionTestObservable()
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
        let observable = TransactionTestObservable()
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
        let observable = TransactionTestObservable()

        // The autoclosure argument should not be called if the observable isn't connected.
        observable.state.begin()
        observable.state.sendIfConnected({ XCTFail(); return ValueChange(from: 0, to: 1) }())
        observable.state.end()

        let sink = MockValueUpdateSink<Int>()
        observable.updates.add(sink)

        sink.expecting(["begin", "0 -> 1", "end"]) {
            observable.state.begin()
            observable.state.sendIfConnected(ValueChange(from: 0, to: 1))
            observable.state.end()
        }

        observable.updates.remove(sink)
    }

    func testSendLater() {
        let observable = TransactionTestObservable()
        let sink = MockValueUpdateSink<Int>()

        observable.updates.add(sink)

        sink.expecting("begin") {
            observable.state.begin()
        }

        observable.state.sendLater(ValueChange(from: 0, to: 1))

        sink.expecting("0 -> 1") {
            observable.state.sendNow()
        }

        sink.expecting("end") {
            observable.state.end()
        }

        observable.updates.remove(sink)
    }

    func testSendUpdate() {
        let observable = TransactionTestObservable()
        let sink = MockValueUpdateSink<Int>()

        observable.updates.add(sink)

        sink.expecting("begin") {
            observable.state.send(.beginTransaction)
        }

        sink.expecting("0 -> 1") {
            observable.state.send(.change(ValueChange(from: 0, to: 1)))
        }

        sink.expecting("end") {
            observable.state.send(.endTransaction)
        }

        observable.updates.remove(sink)
    }

    func testSubscribingToOpenTransaction() {
        let observable = TransactionTestObservable()
        let sink = MockValueUpdateSink<Int>()

        observable.state.begin()

        sink.expecting("begin") {
            observable.updates.add(sink)
        }

        sink.expecting("end") {
            observable.state.end()
        }

        _ = observable.updates.remove(sink)
    }

    func testUnsubscribingFromOpenTransaction() {
        let observable = TransactionTestObservable()
        let sink = MockValueUpdateSink<Int>()

        observable.updates.add(sink)

        sink.expecting("begin") {
            observable.state.begin()
        }
        sink.expecting("end") {
            _ = observable.updates.remove(sink)
        }

        observable.state.end()
    }

    func testPropertiesWithNestedTransactions() {
        let observable = TransactionTestObservable()

        XCTAssertEqual(observable.state.isChanging, false)
        XCTAssertEqual(observable.state.isConnected, false)
        XCTAssertEqual(observable.state.isActive, false)

        // Start an outer transaction.
        observable.state.begin()

        XCTAssertEqual(observable.state.isChanging, true)
        XCTAssertEqual(observable.state.isConnected, false)
        XCTAssertEqual(observable.state.isActive, true)

        // Start a nested transaction.
        observable.state.begin()

        XCTAssertEqual(observable.state.isChanging, true)
        XCTAssertEqual(observable.state.isConnected, false)
        XCTAssertEqual(observable.state.isActive, true)

        observable.state.end()

        XCTAssertEqual(observable.state.isChanging, true)
        XCTAssertEqual(observable.state.isConnected, false)
        XCTAssertEqual(observable.state.isActive, true)

        observable.state.end()

        XCTAssertEqual(observable.state.isChanging, false)
        XCTAssertEqual(observable.state.isConnected, false)
        XCTAssertEqual(observable.state.isActive, false)

        let sink = MockValueUpdateSink<Int>()
        observable.updates.add(sink)

        XCTAssertEqual(observable.state.isChanging, false)
        XCTAssertEqual(observable.state.isConnected, true)
        XCTAssertEqual(observable.state.isActive, true)

        sink.expecting("begin") {
            observable.state.begin()
        }

        XCTAssertEqual(observable.state.isChanging, true)
        XCTAssertEqual(observable.state.isConnected, true)
        XCTAssertEqual(observable.state.isActive, true)

        sink.expecting("end") {
            observable.state.end()
        }

        XCTAssertEqual(observable.state.isChanging, false)
        XCTAssertEqual(observable.state.isConnected, true)
        XCTAssertEqual(observable.state.isActive, true)

        observable.updates.remove(sink)

        XCTAssertEqual(observable.state.isChanging, false)
        XCTAssertEqual(observable.state.isConnected, false)
        XCTAssertEqual(observable.state.isActive, false)
    }

    func testActivation() {
        let observable = TransactionTestObservable()
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

    func send(_ value: ValueUpdate<Int>) {
        state.send(value)
    }

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

