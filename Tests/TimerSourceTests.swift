//
//  TimerSourceTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-03.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import GlueKit

class TimerSourceTests: XCTestCase {

    func testNeverFiringTimer() {
        let queue = dispatch_queue_create("testqueue", nil)

        var timerTimes = [NSDate]()
        let timerSemaphore = dispatch_semaphore_create(0)

        let source = TimerSource(queue: queue) {
            timerTimes.append(NSDate())
            dispatch_semaphore_signal(timerSemaphore)
            return nil
        }

        XCTAssertEqual(timerTimes, [])

        var sinkTimes = [NSDate]()
        let sinkSemaphore = dispatch_semaphore_create(0)
        let connection = source.connect {
            sinkTimes.append(NSDate())
            dispatch_semaphore_signal(sinkSemaphore)
        }

        XCTAssertEqual(0, dispatch_semaphore_wait(timerSemaphore, dispatch_time(3.0)), "Timer source should call timer closure when it is first connected")

        XCTAssertEqual(timerTimes.count, 1)
        XCTAssertEqual(sinkTimes, [])

        connection.disconnect()
    }

    func testRefreshingTimerSource() {
        let queue = dispatch_queue_create("testqueue", nil)

        var signal = false
        var timerTimes = [NSDate]()
        let timerSemaphore = dispatch_semaphore_create(0)

        var triggerDate: NSDate? = nil

        let source = TimerSource(queue: queue) {
            timerTimes.append(NSDate())
            if let date = triggerDate {
                triggerDate = nil
                return date
            }
            else {
                if signal {
                    dispatch_semaphore_signal(timerSemaphore)
                }
                return nil
            }
        }

        XCTAssertEqual(timerTimes, [])

        var sinkTimes = [NSDate]()
        let connection = source.connect {
            sinkTimes.append(NSDate())
        }
        // Timer should have returned nil -> No firing yet

        XCTAssertEqual(sinkTimes, [])

        dispatch_sync(queue) {
            signal = true
            triggerDate = NSDate(timeIntervalSinceNow: 0.1)
            source.start()
        }

        // Timer should return non-nil, clear triggerDate  and signal the semaphore.

        XCTAssertEqual(0, dispatch_semaphore_wait(timerSemaphore, dispatch_time(3.0)))

        XCTAssertEqual(timerTimes.count, 3) // 1: connect, 2: start, 3: after first firing
        XCTAssertEqual(sinkTimes.count, 1) // Should fire only once

        connection.disconnect()
    }

    func testSimplePeriodicSignal() {
        let queue = dispatch_queue_create("testqueue", nil)
        let start = NSDate().dateByAddingTimeInterval(0.2)
        let interval: NSTimeInterval = 0.2

        let source = TimerSource(queue: queue, start: start, interval: interval)

        var ticks = [NSTimeInterval]()
        var count = 0
        let sem = dispatch_semaphore_create(0)
        let connection = source.connect { i in
            let elapsed = NSDate().timeIntervalSinceDate(start)
            ticks.append(elapsed)
            NSLog("tick \(count) at \(elapsed)")
            ++count
            if count >= 3 {
                dispatch_semaphore_signal(sem)
            }
        }

        XCTAssertEqual(0, dispatch_semaphore_wait(sem, dispatch_time(3.0)))
        connection.disconnect()

        let diffs: [NSTimeInterval] = ticks.enumerate().map { tick, elapsed in
            let ideal = NSTimeInterval(tick) * interval
            return elapsed - ideal
        }
        XCTAssertEqual(diffs.filter { $0 < 0 }, [])
    }

}
