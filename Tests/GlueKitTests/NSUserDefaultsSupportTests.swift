//
//  NSUserDefaultsSupportTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-11-02.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest

extension UserDefaults {
    var testValue: Bool {
        get { return self.bool(forKey: "TestKey") }
        set { self.set(newValue, forKey: "TestKey") }
    }
}

class NSUserDefaultsSupportTests: XCTestCase {
    let key = "TestKey"
    let defaults = UserDefaults.standard
    var context: UInt8 = 0
    var notifications: [[NSKeyValueChangeKey: Any]] = []

    override func setUp() {
        super.setUp()
        defaults.removeObject(forKey: key)
    }
    
    override func tearDown() {
        defaults.removeObject(forKey: key)
        super.tearDown()
    }
    
    func testStandardNotifications() {
        defaults.addObserver(self, forKeyPath: key, options: [.old, .new], context: &context)
        defaults.set(true, forKey: key)
        defaults.removeObserver(self, forKeyPath: key, context: &context)
        
        XCTAssertEqual(notifications.count, 1, "Unexpected notifications: \(notifications)")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &self.context {
            print(change ?? "nil")
            notifications.append(change!)
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    func testAny() {
        let updatable = defaults.glue.updatable(forKey: key)
        XCTAssertNil(updatable.value)

        updatable.value = 42

        XCTAssertEqual(updatable.value as? Int, 42)
        XCTAssertEqual(defaults.integer(forKey: key), 42)

        updatable.value = "Foobar"

        XCTAssertEqual(updatable.value as? String, "Foobar")
        XCTAssertEqual(defaults.string(forKey: key), "Foobar")

        let sink = MockValueUpdateSink(updatable)

        sink.expecting(["begin", "Optional(Foobar) -> Optional(23.125)", "end"]) {
            updatable.value = 23.125
        }

        sink.expecting(["begin", "Optional(23.125) -> Optional(Barney)", "end"]) {
            defaults.set("Barney", forKey: key)
        }

        sink.disconnect()
    }

    func testBool() {
        let updatable = defaults.glue.updatable(forKey: key, defaultValue: false)
        XCTAssertFalse(updatable.value)

        updatable.value = true
        XCTAssertEqual(updatable.value, true)

        defaults.set(1, forKey: key)
        XCTAssertEqual(updatable.value, true)

        defaults.set(0, forKey: key)
        XCTAssertEqual(updatable.value, false)

        defaults.set(1.0, forKey: key)
        XCTAssertEqual(updatable.value, true)

        defaults.set("YES", forKey: key)
        XCTAssertEqual(updatable.value, false)

        let sink = MockValueUpdateSink(updatable)

        sink.expecting(["begin", "false -> true", "end"]) {
            updatable.value = true
        }

        sink.expecting(["begin", "true -> false", "end"]) {
            defaults.set(false, forKey: key)
        }
        
        sink.disconnect()
    }

    func testInt() {
        let updatable = defaults.glue.updatable(forKey: key, defaultValue: 0)
        XCTAssertEqual(updatable.value, 0)

        updatable.value = 1
        XCTAssertEqual(updatable.value, 1)

        defaults.set(2, forKey: key)
        XCTAssertEqual(updatable.value, 2)

        defaults.set(nil, forKey: key)
        XCTAssertEqual(updatable.value, 0)

        defaults.set(42.0, forKey: key)
        XCTAssertEqual(updatable.value, 42)

        defaults.set(true, forKey: key)
        XCTAssertEqual(updatable.value, 0) // kCFBooleanTrue is not directly convertible to Int

        defaults.set(42.5, forKey: key)
        XCTAssertEqual(updatable.value, 42)

        defaults.set("23", forKey: key)
        XCTAssertEqual(updatable.value, 0)

        let sink = MockValueUpdateSink(updatable)

        sink.expecting(["begin", "0 -> 3", "end"]) {
            updatable.value = 3
        }

        sink.expecting(["begin", "3 -> 4", "end"]) {
            defaults.set(4, forKey: key)
        }
        
        sink.disconnect()
    }

    func testDouble() {
        let updatable = defaults.glue.updatable(forKey: key, defaultValue: 0.0)
        XCTAssertEqual(updatable.value, 0)

        updatable.value = 1
        XCTAssertEqual(updatable.value, 1)

        defaults.set(2, forKey: key)
        XCTAssertEqual(updatable.value, 2)

        defaults.set(nil, forKey: key)
        XCTAssertEqual(updatable.value, 0)

        defaults.set(42.0, forKey: key)
        XCTAssertEqual(updatable.value, 42)

        defaults.set(true, forKey: key)
        XCTAssertEqual(updatable.value, 0.0) // kCFBooleanTrue is not directly convertible to Int

        defaults.set(42.5, forKey: key)
        XCTAssertEqual(updatable.value, 42.5)

        defaults.set("23", forKey: key)
        XCTAssertEqual(updatable.value, 0)

        let sink = MockValueUpdateSink(updatable)

        sink.expecting(["begin", "0.0 -> 3.0", "end"]) {
            updatable.value = 3
        }

        sink.expecting(["begin", "3.0 -> 4.0", "end"]) {
            defaults.set(4, forKey: key)
        }
        
        sink.disconnect()
    }

    func testString() {
        let updatable = defaults.glue.updatable(forKey: key, as: (String?).self)
        XCTAssertEqual(updatable.value, nil)

        updatable.value = "Foo"
        XCTAssertEqual(updatable.value, "Foo")

        defaults.set(2, forKey: key)
        XCTAssertEqual(updatable.value, nil)

        defaults.set(nil, forKey: key)
        XCTAssertEqual(updatable.value, nil)

        defaults.set(42.0, forKey: key)
        XCTAssertEqual(updatable.value, nil)

        defaults.set(true, forKey: key)
        XCTAssertEqual(updatable.value, nil)

        defaults.set(42.5, forKey: key)
        XCTAssertEqual(updatable.value, nil)

        defaults.set("23", forKey: key)
        XCTAssertEqual(updatable.value, "23")

        let sink = MockValueUpdateSink(updatable)

        sink.expecting(["begin", "Optional(\"23\") -> Optional(\"Fred\")", "end"]) {
            updatable.value = "Fred"
        }

        sink.expecting(["begin", "Optional(\"Fred\") -> Optional(\"Barney\")", "end"]) {
            defaults.set("Barney", forKey: key)
        }
        
        sink.disconnect()
    }
}
