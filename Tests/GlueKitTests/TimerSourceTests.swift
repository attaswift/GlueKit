//
//  TimerSourceTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-03.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

class TimerSourceTests: XCTestCase {

    func testNeverFiringTimer() {
        let queue = DispatchQueue(label: "testqueue", attributes: [])

        var timerTimes = [Date]()
        let timerSemaphore = DispatchSemaphore(value: 0)

        let source = TimerSource(queue: queue) {
            timerTimes.append(Date())
            timerSemaphore.signal()
            return nil
        }

        XCTAssertEqual(timerTimes, [])

        var sinkTimes = [Date]()
        let sinkSemaphore = DispatchSemaphore(value: 0)
        let connection = source.subscribe {
            sinkTimes.append(Date())
            sinkSemaphore.signal()
        }

        XCTAssertEqual(timerSemaphore.wait(timeout: DispatchTime.now() + 3.0), .success, "Timer source should call timer closure when it is first connected")

        XCTAssertEqual(timerTimes.count, 1)
        XCTAssertEqual(sinkTimes, [])

        connection.disconnect()
    }

    func testRefreshingTimerSource() {
        let queue = DispatchQueue(label: "testqueue", attributes: [])

        var signal = false
        var timerTimes = [Date]()
        let timerSemaphore = DispatchSemaphore(value: 0)

        var triggerDate: Date? = nil

        let source = TimerSource(queue: queue) {
            timerTimes.append(Date())
            if let date = triggerDate {
                triggerDate = nil
                return date
            }
            else {
                if signal {
                    timerSemaphore.signal()
                }
                return nil
            }
        }

        XCTAssertEqual(timerTimes, [])

        var sinkTimes = [Date]()
        let connection = source.subscribe {
            sinkTimes.append(Date())
        }
        // Timer should have returned nil -> No firing yet

        XCTAssertEqual(sinkTimes, [])

        queue.sync {
            signal = true
            triggerDate = Date(timeIntervalSinceNow: 0.1)
            source.start()
        }

        // Timer should return non-nil, clear triggerDate  and signal the semaphore.

        XCTAssertEqual(.success, timerSemaphore.wait(timeout: DispatchTime.now() + 3.0))

        XCTAssertEqual(timerTimes.count, 3) // 1: subscribe, 2: start, 3: after first firing
        XCTAssertEqual(sinkTimes.count, 1) // Should fire only once

        connection.disconnect()
    }

    func testSimplePeriodicSignal() {
        let queue = DispatchQueue(label: "testqueue", attributes: [])
        let start = Date().addingTimeInterval(0.2)
        let interval: TimeInterval = 0.2

        let source = TimerSource(queue: queue, start: start, interval: interval)

        var ticks = [TimeInterval]()
        var count = 0
        let sem = DispatchSemaphore(value: 0)
        let connection = source.subscribe { i in
            let elapsed = Date().timeIntervalSince(start)
            ticks.append(elapsed)
            NSLog("tick \(count) at \(elapsed)")
            count += 1
            if count >= 3 {
                sem.signal()
            }
        }

        XCTAssertEqual(.success, sem.wait(timeout: DispatchTime.now() + 3.0))
        connection.disconnect()

        let diffs: [TimeInterval] = ticks.enumerated().map { tick, elapsed in
            let ideal = TimeInterval(tick) * interval
            return elapsed - ideal
        }
        XCTAssertEqual(diffs.filter { $0 < 0 }, [])
    }

}
