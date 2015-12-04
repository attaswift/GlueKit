//
//  KVOSupportTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-03.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

private class Fixture: NSObject {
    dynamic var name: String = ""
    dynamic var count: Int = 0
}

private class RawKVOObserver: NSObject {
    let object: NSObject
    let keyPath: String
    let sink: AnyObject->Void
    var observerContext: Int8 = 0
    var observing: Bool

    init(object: NSObject, keyPath: String, sink: AnyObject->Void) {
        self.object = object
        self.keyPath = keyPath
        self.sink = sink
        self.observing = true
        super.init()
        object.addObserver(self, forKeyPath: keyPath, options: .New, context: &self.observerContext)
    }

    deinit {
        disconnect()
    }

    func disconnect() {
        if observing {
            object.removeObserver(self, forKeyPath: keyPath, context: &self.observerContext)
            observing = false
        }
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == &self.observerContext {
            let newValue = change![NSKeyValueChangeNewKey]!
            sink(newValue)
        }
        else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
}

class KVOSupportTests: XCTestCase {

    func testBasicKVOWithIntegers() {
        let object = Fixture()

        let countSource = object.sourceForKeyPath("count")

        var r = [Int]()
        let c = countSource.toInt().connect { r.append($0) }

        object.count = 1
        object.count = 2
        object.count = 3

        c.disconnect()

        XCTAssertEqual(r, [1, 2, 3])
    }

    func testBasicKVOWithStrings() {
        let object = Fixture()

        var r = [String]()
        let c = object.sourceForKeyPath("name").toString().connect { (s: String)->Void in r.append(s) }

        object.name = "Alice"
        object.name = "Bob"
        object.name = "Charlie"

        c.disconnect()

        object.name = "Daniel"

        XCTAssertEqual(r, ["Alice", "Bob", "Charlie"])
    }


    func testDisconnectActuallyDisconnects() {
        let object = Fixture()

        let countSource = object.sourceForKeyPath("count")

        var r = [Int]()
        let c = countSource.toInt().connect { r.append($0) }

        object.count = 1

        c.disconnect()

        object.count = 2
        object.count = 3

        XCTAssertEqual(r, [1])
    }

    func testSourceRetainsObject() {
        var source: Source<Int>? = nil
        weak var weakObject: NSObject? = nil

        do {
            let object = Fixture()
            weakObject = object

            source = object.sourceForKeyPath("count").toInt()
        }

        XCTAssertNotNil(weakObject)
        source = nil
        XCTAssertNil(weakObject)

        noop(source)
    }

    func testConnectionRetainsObject() {
        var c: Connection? = nil
        weak var weakObject: NSObject? = nil

        do {
            let object = Fixture()
            weakObject = object

            c = object.sourceForKeyPath("count").toInt().connect { _ in }
        }

        XCTAssertNotNil(weakObject)
        c?.disconnect()
        XCTAssertNil(weakObject)
    }

    //MARK: Reentrant observers

    func testReentrantUpdatesInRawKVO() {
        // KVO supports reentrant updates, but it performs them synchronously, always sending the most up to date value.

        let object = Fixture()

        var s = ""
        let observer = RawKVOObserver(object: object, keyPath: "count") { any in
            let i = (any as! NSNumber).integerValue
            s += " (\(i)"
            if i > 0 {
                object.count = i - 1
            }
            s += ")"
        }

        object.count = 3

        // Note deeply nested invocations.
        XCTAssertEqual(s, " (3 (2 (1 (0))))")

        observer.disconnect()
    }

    func testReentrantUpdatesWithSinks() {
        // KVO supports reentrant updates, but it performs them synchronously, always sending the most up to date value.
        // However, our source will serialize reentrant sends so that this is not noticeable.

        let object = Fixture()

        let countSource = object.sourceForKeyPath("count")

        var s = ""
        let c = countSource.toInt().connect { i in
            s += " (\(i)"
            if i > 0 {
                object.count = i - 1
            }
            s += ")"
        }

        object.count = 3

        // Contrast this with the previous test.
        XCTAssertEqual(s, " (3) (2) (1) (0)")
        
        c.disconnect()
    }
    

    func testReentrantUpdatesInRawKVO2() {
        // KVO supports reentrant updates, but it performs them synchronously, always sending the most up to date value.

        let object = Fixture()

        var s = ""
        let observer1 = RawKVOObserver(object: object, keyPath: "count") { any in
            let i = (any as! NSNumber).integerValue
            s += " (\(i)"
            if i > 0 {
                object.count = i - 1
            }
            s += ")"
        }
        let observer2 = RawKVOObserver(object: object, keyPath: "count") { any in
            let i = (any as! NSNumber).integerValue
            s += " (\(i)"
            if i > 0 {
                object.count = i - 1
            }
            s += ")"
        }

        object.count = 2

        // Note deeply nested invocations and how observers always receive the latest value (shortening the cascade).
        XCTAssertEqual(s, " (2 (1 (0) (0)) (0)) (0)")
        
        observer1.disconnect()
        observer2.disconnect()
    }


    func testReentrantUpdatesWithSinks2() {
        // KVO supports reentrant updates, but it performs them synchronously, always sending the most up to date value.
        // However, our source will serialize reentrant sends so that this is not noticeable.

        let object = Fixture()

        let countSource = object.sourceForKeyPath("count")

        var s = ""
        let c1 = countSource.toInt().connect { i in
            s += " (\(i)"
            if i > 0 {
                object.count = i - 1
            }
            s += ")"
        }
        let c2 = countSource.toInt().connect { i in
            s += " (\(i)"
            if i > 0 {
                object.count = i - 1
            }
            s += ")"
        }

        object.count = 2

        // Contrast this with the previous test.
        XCTAssertEqual(s, " (2) (2) (1) (1) (1) (1) (0) (0) (0) (0) (0) (0) (0) (0)")

        c1.disconnect()
        c2.disconnect()
    }



}
