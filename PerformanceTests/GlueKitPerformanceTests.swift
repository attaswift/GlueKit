//
//  GlueKitPerformanceTests.swift
//  GlueKitPerformanceTests
//
//  Created by Károly Lőrentey on 2015-12-04.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
import GlueKit

class SignalPerformanceTests: XCTestCase {

    func testSendPerformance() {
        let iterations = 120 * 1000
        self.measureMetrics(SignalPerformanceTests.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            var count = 0
            let signal = Signal<Int>()
            let c = signal.connect { i in count += 1 }

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

        self.measureMetrics(SignalPerformanceTests.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            var count = 0
            let signal = Signal<Int>()
            let c = signal.connect { i in count += 1 }

            let queues = (1...queueCount).map { i in DispatchQueue(label: "com.github.lorentey.GlueKit.testQueue \(i)") }

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
            connections.append(end.connect(new))
            end = new
        }

        let count = 100
        self.measureMetrics(SignalPerformanceTests.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            var r = [Int]()
            r.reserveCapacity(1000)
            let c = end.connect { i in r.append(i) }

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
