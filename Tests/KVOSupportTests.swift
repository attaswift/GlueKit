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
    dynamic var optional: String? = nil
}

private class RawKVOObserver: NSObject {
    let object: NSObject
    let keyPath: String
    let sink: (AnyObject) -> Void
    var observerContext: Int8 = 0
    var observing: Bool

    init(object: NSObject, keyPath: String, sink: @escaping (AnyObject) -> Void) {
        self.object = object
        self.keyPath = keyPath
        self.sink = sink
        self.observing = true
        super.init()
        object.addObserver(self, forKeyPath: keyPath, options: .new, context: &self.observerContext)
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

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &self.observerContext {
            let newValue = change![NSKeyValueChangeKey.newKey]!
            sink(newValue as AnyObject)
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

class KVOSupportTests: XCTestCase {

    func testBasicKVOWithIntegers() {
        let object = Fixture()

        let countSource = object.sourceForKeyPath("count")

        var r = [Int]()
        let c = countSource.asInt.connect { r.append($0) }

        object.count = 1
        object.count = 2
        object.count = 3

        c.disconnect()

        XCTAssertEqual(r, [1, 2, 3])
    }

    func testBasicKVOWithStrings() {
        let object = Fixture()

        var r = [String]()
        let c = object.sourceForKeyPath("name").asString.connect { (s: String) -> Void in r.append(s) }

        object.name = "Alice"
        object.name = "Bob"
        object.name = "Charlie"

        c.disconnect()

        object.name = "Daniel"

        XCTAssertEqual(r, ["Alice", "Bob", "Charlie"])
    }

    func testBasicKVOWithOptionals() {
        let object = Fixture()

        var r = [String?]()
        let c = object.sourceForKeyPath("optional").connect { (v: AnyObject?) -> Void in
            if let s = v as? String {
                r.append(s)
            }
            else {
                XCTAssertNil(v)
                r.append(nil)
            }
        }

        object.optional = "Alice"
        object.optional = nil
        object.optional = "Bob"
        object.optional = nil
        object.optional = nil

        c.disconnect()

        object.optional = "Daniel"
        object.optional = nil

        let expected: [String?] = ["Alice", nil, "Bob", nil, nil]
        XCTAssert(r.elementsEqual(expected, by: { $0 == $1 }))
    }


    func testDisconnectActuallyDisconnects() {
        let object = Fixture()

        let countSource = object.sourceForKeyPath("count")

        var r = [Int]()
        let c = countSource.asInt.connect { r.append($0) }

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

            source = object.sourceForKeyPath("count").asInt
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

            c = object.sourceForKeyPath("count").asInt.connect { _ in }
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
            let i = (any as! NSNumber).intValue
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
        let c = countSource.asInt.connect { i in
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
            let i = (any as! NSNumber).intValue
            s += " (\(i)"
            if i > 0 {
                object.count = i - 1
            }
            s += ")"
        }
        let observer2 = RawKVOObserver(object: object, keyPath: "count") { any in
            let i = (any as! NSNumber).intValue
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
        let c1 = countSource.asInt.connect { i in
            s += " (\(i)"
            if i > 0 {
                object.count = i - 1
            }
            s += ")"
        }
        let c2 = countSource.asInt.connect { i in
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
