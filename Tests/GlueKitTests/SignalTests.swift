//
//  SignalTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

class SignalTests: XCTestCase {

    //MARK: Test add/remove API

    func test_AddRemove_SinkReceivesValuesWhileAdded() {
        let signal = Signal<Int>()
        let sink = MockSink<Int>()

        sink.expectingNothing {
            signal.send(1)
        }

        signal.add(sink)

        sink.expecting([2, 3, 4]) {
            signal.send(2)
            signal.send(3)
            signal.send(4)
        }

        signal.remove(sink)

        sink.expectingNothing {
            signal.send(5)
        }
    }

    func test_AddRemove_SignalRetainsAddedSinks() {
        let signal = Signal<Int>()

        weak var weakSink: MockSink<Int>? = nil

        do {
            let sink = MockSink<Int>()
            weakSink = sink

            signal.add(sink)
        }

        XCTAssertNotNil(weakSink)

        signal.remove(weakSink!)

        XCTAssertNil(weakSink)
    }

    //MARK: Test subscribe API

    func test_Connect_DisconnectingTheConnection() {
        let signal = Signal<Int>()

        var received = [Int]()

        let c = signal.subscribe { received.append($0) }

        signal.send(1)
        c.disconnect()
        signal.send(2)

        XCTAssertEqual(received, [1])
        noop(c)
    }

    func test_Connect_ReleasingConnectionAutomaticallyDisconnects() {
        let signal = Signal<Int>()
        var values = [Int]()

        var c: Connection? = signal.subscribe { values.append($0) }
        signal.send(1)
        c = nil
        signal.send(2)

        XCTAssertEqual(values, [1])
        noop(c)
    }

    func test_Connect_DuplicateDisconnect() {
        let signal = Signal<Int>()

        let c = signal.subscribe { i in }

        // It is OK to call disconnect twice.
        c.disconnect()
        c.disconnect()
    }

    func test_Connect_MultipleConnections() {
        let signal = Signal<Int>()

        signal.send(1)

        var a = [Int]()
        let c1 = signal.subscribe { i in a.append(i) }

        signal.send(2)

        var b = [Int]()
        let c2 = signal.subscribe { i in b.append(i) }

        signal.send(3)

        c1.disconnect()

        signal.send(4)

        c2.disconnect()

        signal.send(5)

        XCTAssertEqual(a, [2, 3])
        XCTAssertEqual(b, [3, 4])
    }

    func test_Connect_ConnectionRetainsTheSignal() {
        var values = [Int]()
        weak var weakSignal: Signal<Int>? = nil
        weak var weakConnection: Connection? = nil
        do {
            let connection: Connection
            do {
                let signal = Signal<Int>()
                weakSignal = signal
                connection = signal.subscribe { i in values.append(i) }
                weakConnection = .some(connection)

                signal.send(1)
            }

            XCTAssertNotNil(weakSignal)
            XCTAssertNotNil(weakConnection)
            withExtendedLifetime(connection) {}
        }
        XCTAssertNil(weakSignal)
        XCTAssertNil(weakConnection)
        XCTAssertEqual(values, [1])
    }

    func test_Connect_DisconnectingConnectionReleasesResources() {
        weak var weakSignal: Signal<Int>? = nil
        weak var weakResource: NSMutableArray? = nil

        let connection: Connection
        do {
            let signal = Signal<Int>()
            weakSignal = signal

            let resource = NSMutableArray()
            weakResource = resource

            connection = signal.subscribe { i in
                resource.add(i)
            }
            signal.send(1)
        }

        XCTAssertNotNil(weakSignal)
        XCTAssertNotNil(weakResource)

        XCTAssertEqual(weakResource, NSArray(object: 1))

        connection.disconnect()

        XCTAssertNil(weakSignal)
        XCTAssertNil(weakResource) 
    }

    func test_Connect_SourceDoesNotRetainConnection() {
        var values = [Int]()
        weak var weakConnection: Connection? = nil
        let signal = Signal<Int>()
        do {
            let connection = signal.subscribe { values.append($0) }
            weakConnection = connection

            signal.send(1)
            noop(connection)
        }

        signal.send(2)
        XCTAssertNil(weakConnection)

        XCTAssertEqual(values, [1])
    }

    //MARK: Test sinks adding and removing connections

    func test_Connect_AddingAConnectionInASink() {
        let signal = Signal<Int>()

        var v1 = [Int]()
        var c1: Connection? = nil

        var v2 = [Int]()
        var c2: Connection? = nil

        signal.send(1)

        c1 = signal.subscribe { i in
            v1.append(i)
            if c2 == nil {
                c2 = signal.subscribe { v2.append($0) }
            }
        }

        XCTAssertNil(c2)

        signal.send(2)

        XCTAssertNotNil(c2)

        signal.send(3)

        c1?.disconnect()
        c2?.disconnect()

        signal.send(4)

        XCTAssertEqual(v1, [2, 3])
        XCTAssertEqual(v2, [3])
    }

    func test_Connect_RemovingConnectionWhileItIsBeingTriggered() {
        let signal = Signal<Int>()

        signal.send(1)

        var r = [Int]()

        var c: Connection? = nil
        c = signal.subscribe { i in
            r.append(i)
            c?.disconnect()
        }

        signal.send(2)
        signal.send(3)
        signal.send(4)

        XCTAssertEqual(r, [2])
    }

    func test_Connect_RemovingNextConnection() {
        let signal = Signal<Int>()

        var r = [Int]()

        var c1: Connection? = nil
        var c2: Connection? = nil

        signal.send(0)

        // We don't know which connection fires first.
        // After disconnect() returns, the connection must not fire any more -- even if disconnect is called by a sink.

        c1 = signal.subscribe { i in
            r.append(i)
            c2?.disconnect()
            c2 = nil
        }

        c2 = signal.subscribe { i in
            r.append(i)
            c1?.disconnect()
            c1 = nil
        }

        XCTAssertTrue(c1 != nil && c2 != nil)

        signal.send(1)
        XCTAssertTrue((c1 == nil) != (c2 == nil))

        signal.send(2)
        signal.send(3)
        XCTAssertTrue((c1 == nil) != (c2 == nil))

        XCTAssertEqual(r, [1, 2, 3])
    }


    func test_Connect_RemovingAndReaddingConnectionsAlternately() {
        // This is a weaker test of the semantics of subscribe/disconnect nested in sinks.
        let signal = Signal<Int>()

        var r1 = [Int]()
        var r2 = [Int]()

        var c1: Connection? = nil
        var c2: Connection? = nil

        var sink1: ((Int) -> Void)!
        var sink2: ((Int) -> Void)!

        sink1 = { i in
            r1.append(i)
            c1?.disconnect()
            c2 = signal.subscribe(sink2)
        }

        sink2 = { i in
            r2.append(i)
            c2?.disconnect()
            c1 = signal.subscribe(sink1)
        }

        c1 = signal.subscribe(sink1)
        for i in 1...6 {
            signal.send(i)
        }

        XCTAssertEqual(r1, [1, 3, 5])
        XCTAssertEqual(r2, [2, 4, 6])
    }

    func test_Connect_SinkDisconnectingThenReconnectingItself() {
        // This is a weaker test of the semantics of subscribe/disconnect nested in sinks.
        let signal = Signal<Int>()

        var r = [Int]()
        var c: Connection? = nil
        var sink: ((Int) -> Void)!

        sink = { i in
            r.append(i)
            c?.disconnect()
            c = signal.subscribe(sink)
        }
        c = signal.subscribe(sink)
        
        for i in 1...6 {
            signal.send(i)
        }

        c?.disconnect()

        XCTAssertEqual(r, [1, 2, 3, 4, 5, 6])
    }

    //MARK: Test reentrant sends

    func test_Reentrancy_SinksAreNeverNested() {
        let signal = Signal<Int>()

        var s = ""

        let c = signal.subscribe { i in
            s += " (\(i)"
            if i > 0 {
                signal.send(i - 1) // This send is asynchronous. The value is sent at the end of the outermost send.
            }
            s += ")"
        }

        signal.send(3)
        c.disconnect()

        XCTAssertEqual(s, " (3) (2) (1) (0)")
    }

    func test_Reentrancy_SinksReceiveAllValuesSentAfterTheyConnectedEvenWhenReentrant() {
        var s = ""
        let signal = Signal<Int>()

        // Let's do an exponential cascade of decrements with two sinks:
        var values1 = [Int]()
        let c1 = signal.subscribe { i in
            values1.append(i)
            s += " (\(i)"
            if i > 0 {
                signal.send(i - 1)
            }
            s += ")"
        }

        var values2 = [Int]()
        let c2 = signal.subscribe { i in
            values2.append(i)
            s += " (\(i)"
            if i > 0 {
                signal.send(i - 1)
            }
            s += ")"
        }

        signal.send(2)

        // There should be no nesting and both sinks should receive all sent values, in correct order.
        XCTAssertEqual(values1, [2, 1, 1, 0, 0, 0, 0])
        XCTAssertEqual(values2, [2, 1, 1, 0, 0, 0, 0])
        XCTAssertEqual(s, " (2) (2) (1) (1) (1) (1) (0) (0) (0) (0) (0) (0) (0) (0)")
        
        c1.disconnect()
        c2.disconnect()
    }

    func test_Reentrancy_SinksDoNotReceiveValuesSentToTheSignalBeforeTheyWereConnected() {
        let signal = Signal<Int>()

        var values1 = [Int]()
        var values2 = [Int]()

        var c2: Connection? = nil
        let c1 = signal.subscribe { i in
            values1.append(i)
            if i == 3 && c2 == nil {
                signal.send(0) // This should not reach c2
                c2 = signal.subscribe { i in
                    values2.append(i)
                }
            }
        }
        signal.send(1)
        signal.send(2)
        signal.send(3)
        signal.send(4)
        signal.send(5)

        XCTAssertEqual(values1, [1, 2, 3, 0, 4, 5])
        XCTAssertEqual(values2, [4, 5])

        c1.disconnect()
        c2?.disconnect()
    }

    //MARK: sendLater / sendNow

    func test_Reentrancy_SendLaterSendsValueLater() {
        let signal = Signal<Int>()

        var r = [Int]()
        let c = signal.subscribe { r.append($0) }

        signal.sendLater(0)
        signal.sendLater(1)
        signal.sendLater(2)

        XCTAssertEqual(r, [])

        signal.sendNow()

        XCTAssertEqual(r, [0, 1, 2])

        c.disconnect()
    }

    func test_Reentrancy_SendLaterDoesntSendValueToSinksConnectedLater() {
        let signal = Signal<Int>()

        signal.sendLater(0)
        signal.sendLater(1)
        signal.sendLater(2)

        var r = [Int]()
        let c = signal.subscribe { r.append($0) }

        signal.sendLater(3)
        signal.sendLater(4)

        XCTAssertEqual(r, [])

        signal.sendNow()

        XCTAssertEqual(r, [3, 4])

        c.disconnect()
    }

    func test_Reentrancy_SendLaterDoesntSendValueToSinksConnectedLaterEvenIfThereAreOtherSinks() {
        let signal = Signal<Int>()

        var r1 = [Int]()
        let c1 = signal.subscribe { r1.append($0) }

        signal.sendLater(0)
        signal.sendLater(1)
        signal.sendLater(2)

        var r2 = [Int]()
        let c2 = signal.subscribe { r2.append($0) }

        signal.sendLater(3)
        signal.sendLater(4)

        XCTAssertEqual(r1, [])
        XCTAssertEqual(r2, [])

        signal.sendNow()

        XCTAssertEqual(r1, [0, 1, 2, 3, 4])
        XCTAssertEqual(r2, [3, 4])

        c1.disconnect()
        c2.disconnect()
    }


    func test_Reentrancy_SendLaterUsingCounter() {
        let counter = Counter()

        var s = ""
        let c = counter.subscribe { value in
            s += " (\(value)"
            if value < 5 {
                counter.increment()
            }
            s += ")"
        }

        let v = counter.increment()
        XCTAssertEqual(v, 1)
        XCTAssertEqual(s, " (1) (2) (3) (4) (5)")

        c.disconnect()
    }
}

private class Counter: SourceType {
    typealias Value = Int

    private let lock = Lock()
    private var counter: Int = 0
    private var signal = Signal<Int>()

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Int {
        signal.add(sink)
    }

    @discardableResult
    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Int {
        return signal.remove(sink)
    }

    @discardableResult
    func increment() -> Int {
        let value: Int = lock.withLock {
            self.counter += 1
            let v = self.counter
            signal.sendLater(v)
            return v
        }
        signal.sendNow()
        return value
    }
}
