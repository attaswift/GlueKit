//
//  GlueKitPerformanceTests.swift
//  GlueKitPerformanceTests
//
//  Created by Károly Lőrentey on 2015-12-04.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit

private struct EmptySink: SinkType {
    let id: Int

    func receive(_ value: Int) {
        // Do nothing
    }
    var hashValue: Int { return id }
    static func ==(left: EmptySink, right: EmptySink) -> Bool { return left.id == right.id }
}

private class TestSink: SinkType {
    var count = 0

    func receive(_ value: Int) {
        count += 1
    }
}

private struct RefCountingSink: SinkType {
    let object: TestSink
    let id: Int

    func receive(_ value: Int) {
        // Do nothing
    }
    var hashValue: Int { return id }
    static func ==(left: RefCountingSink, right: RefCountingSink) -> Bool { return left.id == right.id }
}


private struct TestMethodSink: SinkType {
    let object: TestSink
    let method: (TestSink) -> (Int) -> Void
    let id: Int
    func receive(_ value: Int) {
        method(object)(value)
    }
    var hashValue: Int { return ObjectIdentifier(object).hashValue ^ id }
    static func ==(left: TestMethodSink, right: TestMethodSink) -> Bool { return left.object === right.object && left.id == right.id }
}

private struct TestPartiallyAppliedMethodSink: SinkType {
    let object: TestSink
    let method: (Int) -> Void
    let id: Int
    func receive(_ value: Int) {
        method(value)
    }
    var hashValue: Int { return ObjectIdentifier(object).hashValue ^ id }
    static func ==(left: TestPartiallyAppliedMethodSink, right: TestPartiallyAppliedMethodSink) -> Bool {
        return left.object === right.object && left.id == right.id
    }
}

private struct HardwiredMethodSink: SinkType {
    let object: TestSink
    let id: Int
    func receive(_ value: Int) {
        object.receive(value)
    }
    var hashValue: Int { return ObjectIdentifier(object).hashValue ^ id }
    static func ==(left: HardwiredMethodSink, right: HardwiredMethodSink) -> Bool { return left.object === right.object && left.id == right.id }
}

extension XCTestCase {
    func measureDelayed(_ body: @escaping () -> ()) {
        self.measureMetrics(XCTestCase.defaultPerformanceMetrics, automaticallyStartMeasuring: false, for: body)
    }
}

class SignalSubscriptionTests: XCTestCase {

    func test_subscribe_EmptySink() {
        let count = 100_000

        self.measureDelayed {
            let signal = Signal<Int>()

            self.startMeasuring()
            for i in 0 ..< count {
                signal.add(EmptySink(id: i))
            }
            self.stopMeasuring()

            signal.send(1)

            for i in 0 ..< count {
                signal.remove(EmptySink(id: i))
            }

            XCTAssertFalse(signal.isConnected)
        }
    }

    func test_subscribe_RefCountingSink() {
        let count = 100_000

        self.measureDelayed {

            let signal = Signal<Int>()

            let object = TestSink()

            self.startMeasuring()
            for i in 0 ..< count {
                signal.add(RefCountingSink(object: object, id: i))
            }
            self.stopMeasuring()

            signal.send(1)

            for i in 0 ..< count {
                signal.remove(RefCountingSink(object: object, id: i))
            }
            
            XCTAssertFalse(signal.isConnected)
        }
    }

    func test_subscribe_MethodSink() {
        let count = 100_000

        self.measureDelayed {

            let signal = Signal<Int>()
            let object = TestSink()

            self.startMeasuring()
            for i in 0 ..< count {
                signal.add(TestMethodSink(object: object, method: TestSink.receive, id: i))
            }
            self.stopMeasuring()

            signal.send(1)

            for i in 0 ..< count {
                signal.remove(TestMethodSink(object: object, method: TestSink.receive, id: i))
            }

            XCTAssertFalse(signal.isConnected)
            XCTAssertEqual(object.count, count)
        }
    }

    func test_subscribe_PartiallyAppliedMethodSink() {
        let count = 100_000

        self.measureDelayed {

            let signal = Signal<Int>()
            let object = TestSink()

            self.startMeasuring()
            for i in 0 ..< count {
                signal.add(TestPartiallyAppliedMethodSink(object: object, method: object.receive, id: i))
            }
            self.stopMeasuring()

            signal.send(1)

            for i in 0 ..< count {
                signal.remove(TestPartiallyAppliedMethodSink(object: object, method: object.receive, id: i))
            }

            XCTAssertFalse(signal.isConnected)
            XCTAssertEqual(object.count, count)
        }
    }


    func test_subscribe_HardwiredMethodSink() {
        let count = 100_000

        self.measureDelayed {

            let signal = Signal<Int>()
            let object = TestSink()

            self.startMeasuring()
            for i in 0 ..< count {
                signal.add(HardwiredMethodSink(object: object, id: i))
            }
            self.stopMeasuring()

            signal.send(1)

            for i in 0 ..< count {
                signal.remove(HardwiredMethodSink(object: object, id: i))
            }

            XCTAssertFalse(signal.isConnected)
            //XCTAssertEqual(object.count, count)
        }
    }


    func test_subscribe_Closures() {
        let count = 100_000

        self.measureDelayed {

            let signal = Signal<Int>()
            var received = 0
            var connections: [Connection] = []

            self.startMeasuring()
            for _ in 0 ..< count {
                let c = signal.subscribe { _ in received += 1 }
                connections.append(c)
            }
            self.stopMeasuring()

            signal.send(1)

            for c in connections {
                c.disconnect()
            }

            XCTAssertFalse(signal.isConnected)
            XCTAssertEqual(received, count)
        }
    }
}

class SignalUnsubscriptionTests: XCTestCase {

    func test_unsubscribe_emptySinks() {
        let count = 100_000

        self.measureDelayed {
            let signal = Signal<Int>()
            for i in 0 ..< count {
                signal.add(EmptySink(id: i))
            }

            signal.send(1)

            self.startMeasuring()
            for i in 0 ..< count {
                signal.remove(EmptySink(id: i))
            }
            self.stopMeasuring()

            XCTAssertFalse(signal.isConnected)
        }
    }
}

class SignalSendTests: XCTestCase {

    func test_send_toSink() {
        let iterations = 200_000

        measureDelayed {
            let signal = Signal<Int>()
            let sink = TestSink()
            signal.add(sink)
            self.startMeasuring()
            for i in 1...iterations {
                signal.send(i)
            }
            self.stopMeasuring()
            signal.remove(sink)
            XCTAssertEqual(sink.count, iterations)
        }
    }

    func test_send_toClosure() {
        // Sending to a closure should take roughly the same time as sending to a sink.
        let iterations = 200_000

        self.measureDelayed {
            var count = 0
            let signal = Signal<Int>()
            let c = signal.subscribe { i in count += 1 }

            self.startMeasuring()
            for i in 1...iterations {
                signal.send(i)
            }
            self.stopMeasuring()

            c.disconnect()
            XCTAssertEqual(count, iterations)
        }
    }

    func testConcurrentSendPerformance() {
        let queueCount = 4
        let iterations = 30000

        self.measureDelayed {
            var count = 0
            let signal = Signal<Int>()
            let c = signal.subscribe { i in count += 1 }

            let queues = (1...queueCount).map { i in DispatchQueue(label: "org.attaswift.GlueKit.testQueue \(i)") }

            let group = DispatchGroup()
            self.startMeasuring()
            for q in queues {
                q.async(group: group) {
                    for i in 1...iterations {
                        signal.send(i)
                    }
                }
            }
            group.wait()
            self.stopMeasuring()

            c.disconnect()
            XCTAssertEqual(count, iterations * queueCount)
        }
    }

    func testChainedSendPerformance() {
        // Chain 1000 signals together, then send a bunch of numbers through the chain.
        var connections: [Connection] = []
        let start = Signal<Int>()
        var end = start
        (1...1000).forEach { _ in
            let new = Signal<Int>()
            connections.append(end.subscribe(new.send))
            end = new
        }

        let count = 100
        self.measureDelayed {
            var r = [Int]()
            r.reserveCapacity(1000)
            let c = end.subscribe { i in r.append(i) }

            for i in 1...10 {
                start.send(i)
            }
            r.removeAll(keepingCapacity: true)

            self.startMeasuring()
            for i in 1...count {
                start.send(i)
            }
            self.stopMeasuring()

            c.disconnect()
            XCTAssertEqual(r.count, count)
        }
    }
}
