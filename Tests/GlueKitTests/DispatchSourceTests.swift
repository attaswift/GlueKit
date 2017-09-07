//
//  DispatchSourceTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-11-02.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit


class DispatchSourceTests: XCTestCase {
    func testDispatchQueue() {
        let signal = Signal<Int>()

        let queue = DispatchQueue(label: "org.attaswift.GlueKit.test")
        let semaphore = DispatchSemaphore(value: 1)
        var r: [Int] = []

        let connection = signal.dispatch(on: queue).subscribe { value in
            semaphore.wait()
            r.append(value)
            semaphore.signal()
        }

        semaphore.wait()
        signal.send(1)
        XCTAssertEqual(r, [])
        semaphore.signal()
        queue.sync {
            XCTAssertEqual(r, [1])
        }

        connection.disconnect()
    }

    func testOperationQueue() {
        let signal = Signal<Int>()

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let semaphore = DispatchSemaphore(value: 1)
        var r: [Int] = []

        let connection = signal.dispatch(on: queue).subscribe { value in
            XCTAssertEqual(OperationQueue.current, queue)
            semaphore.wait()
            r.append(value)
            semaphore.signal()
        }

        semaphore.wait()
        signal.send(1)
        XCTAssertEqual(r, [])
        semaphore.signal()

        queue.waitUntilAllOperationsAreFinished()
        XCTAssertEqual(r, [1])

        queue.addOperation {
            signal.send(2)
        }

        queue.waitUntilAllOperationsAreFinished()

        semaphore.wait()
        XCTAssertEqual(r, [1, 2])
        semaphore.signal()

        connection.disconnect()
    }
}
