//
//  GlueKitPerformanceTests.swift
//  GlueKitPerformanceTests
//
//  Created by Károly Lőrentey on 2015-12-04.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import GlueKit

class SignalPerformanceTests: XCTestCase {

    func testSendPerformance() {
        let iterations = 60 * 1000
        self.measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            var count = 0
            let signal = Signal<Int>()
            let c = signal.connect { i in count++ }

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
        let iterations = 15000

        self.measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            var count = 0
            let signal = Signal<Int>()
            let c = signal.connect { i in count++ }

            let queues = (1...queueCount).map { i in dispatch_queue_create("com.github.lorentey.GlueKit.testQueue \(i)", nil) }

            let group = dispatch_group_create()
            self.startMeasuring()
            for q in queues {
                dispatch_group_async(group, q) {
                    for i in 1...iterations {
                        signal.send(i)
                    }
                }
            }
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
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
            connections.append(end.connect(new))
            end = new
        }

        let count = 50
        self.measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            var r = [Int]()
            r.reserveCapacity(1000)
            let c = end.connect { i in r.append(i) }

            for i in 1...10 {
                start.send(i)
            }
            r.removeAll(keepCapacity: true)

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

class SynchronousSignalPerformanceTests: XCTestCase {

    func testSendPerformance() {
        let iterations = 60 * 1000
        self.measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            var count = 0
            let signal = Signal<Int>()
            let c = signal.connect { i in count++ }

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
        let iterations = 15000

        self.measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            var count = 0
            let signal = SynchronousSignal<Int>()
            let c = signal.connect { i in count++ }

            let queues = (1...queueCount).map { i in dispatch_queue_create("com.github.lorentey.GlueKit.testQueue \(i)", nil) }

            let group = dispatch_group_create()
            self.startMeasuring()
            for q in queues {
                dispatch_group_async(group, q) {
                    for i in 1...iterations {
                        signal.send(i)
                    }
                }
            }
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
            self.stopMeasuring()

            c.disconnect()
            XCTAssertEqual(count, iterations * queueCount)
        }
    }
    
    func testChainedSendPerformance() {
        // Chain a 1000 signals together, then send a bunch of numbers through the chain.
        var connections: [Connection] = []
        let start = SynchronousSignal<Int>()
        var end = start
        (1...1000).forEach { _ in
            let new = SynchronousSignal<Int>()
            connections.append(end.connect(new))
            end = new
        }

        let count = 50
        self.measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            var r = [Int]()
            r.reserveCapacity(1000)
            let c = end.connect { i in r.append(i) }

            for i in 1...10 {
                start.send(i)
            }
            r.removeAll(keepCapacity: true)

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
