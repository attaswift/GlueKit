//
//  NotificationCenterSupportTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-04.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest

private let center = NotificationCenter.default

private func post(_ value: Int) { post("TestNotification", value) }
private func post(_ name: String, _ value: Int) {
    center.post(name: Notification.Name(rawValue: name), object: nil, userInfo: ["Value": value])
}

let testNotification = NSNotification.Name("TestNotification")

class NotificationCenterSupportTests: XCTestCase {

    func testSimpleNotification() {
        var r = [Int]()

        post(1)
        let c = center.glue.source(forName: testNotification).subscribe { notification in
            r.append((notification as NSNotification).userInfo!["Value"] as! Int)
        }

        post(2)
        post(3)

        c.disconnect()

        post(4)

        XCTAssertEqual(r, [2, 3])
    }

    func testReentrancyInRawNotificationCenter() {
        // The notification center supports reentrancy but it is synchronous, just like KVO - except it doesn't force "latest" values

        var s = ""
        let observer = center.addObserver(forName: testNotification, object: nil, queue: nil) { notification in
            let value = (notification as NSNotification).userInfo!["Value"] as! Int
            s += " (\(value)"
            if value > 0 {
                post(value - 1)
            }
            s += ")"
        }

        post(3)

        XCTAssertEqual(s, " (3 (2 (1 (0))))")

        center.removeObserver(observer)
    }

    func testReentrancyInGlueKit() {
        var s = ""
        let c = center.glue.source(forName: testNotification).subscribe { notification in
            let value = (notification as NSNotification).userInfo!["Value"] as! Int
            s += " (\(value)"
            if value > 0 {
                post(value - 1)
            }
            s += ")"
        }

        post(3)

        // Nicely serialized invocations.
        XCTAssertEqual(s, " (3) (2) (1) (0)")

        c.disconnect()
    }
    
    func testReentrancyCascadeInRawNotificationCenter() {
        // The notification center supports reentrancy but it is synchronous, just like KVO - except it doesn't force "latest" values

        var firstIndex: Int? = nil
        var receivedValues: [[Int]] = [[], []]
        var s = ""
        let block: (Int) -> (Notification) -> Void = { index in
            return { notification in
                if firstIndex == nil { firstIndex = index }
                let value = (notification as NSNotification).userInfo!["Value"] as! Int
                receivedValues[index].append(value)
                s += " (\(value)"
                if value > 0 {
                    post(value - 1)
                }
                s += ")"
            }
        }

        let observer1 = center.addObserver(forName: testNotification, object: nil, queue: nil, using: block(0))
        let observer2 = center.addObserver(forName: testNotification, object: nil, queue: nil, using: block(1))

        post(2)

        // Note nested invocations and strange ordering of delivered values.
        XCTAssertEqual(receivedValues[firstIndex!], [2, 1, 0, 0, 1, 0, 0])
        XCTAssertEqual(receivedValues[1 - firstIndex!], [0, 1, 0, 2, 0, 1, 0])
        XCTAssertEqual(s, " (2 (1 (0) (0)) (1 (0) (0))) (2 (1 (0) (0)) (1 (0) (0)))")

        center.removeObserver(observer1)
        center.removeObserver(observer2)
    }

    func testReentrancyCascadeInGlueKit() {
        var firstIndex: Int? = nil
        var receivedValues: [[Int]] = [[], []]
        var s = ""
        let block: (Int) -> (Notification) -> Void = { index in
            return { notification in
                if firstIndex == nil { firstIndex = index }
                let value = (notification as NSNotification).userInfo!["Value"] as! Int
                receivedValues[index].append(value)
                s += " (\(value)"
                if value > 0 {
                    post(value - 1)
                }
                s += ")"
            }
        }

        let source = center.glue.source(forName: testNotification)

        let c1 = source.subscribe(block(0))
        let c2 = source.subscribe(block(1))

        post(2)

        // Nicely serialized invocations. Values are progressing monotonically and there are no nested calls.
        // Note though that this wouldn't happen if the source wasn't shared above!
        XCTAssertEqual(receivedValues[0], [2, 1, 1, 0, 0, 0, 0])
        XCTAssertEqual(receivedValues[1], [2, 1, 1, 0, 0, 0, 0])
        XCTAssertEqual(s, " (2) (2) (1) (1) (1) (1) (0) (0) (0) (0) (0) (0) (0) (0)")

        c1.disconnect()
        c2.disconnect()
    }

}
