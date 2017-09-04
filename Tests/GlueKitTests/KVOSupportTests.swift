//
//  KVOSupportTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-03.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

private class Fixture: NSObject {
    var _name: String = ""
    var _count: Int = 0
    var _optional: String? = nil
    var _next: Fixture? = nil

    @objc dynamic var name: String {
        get { return _name }
        set { _name = newValue }
    }
    @objc dynamic var count: Int {
        get { return _count }
        set { _count = newValue }
    }
    @objc dynamic var optional: String? {
        get { return _optional }
        set { _optional = newValue }
    }
    @objc dynamic var next: Fixture? {
        get { return _next }
        set { _next = newValue }
    }
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

    func test_changes_BasicKVOWithIntegers() {
        let object = Fixture()

        let count = object.observable(for: \.count)

        var r = [Int]()
        let c = count.changes.subscribe { r.append($0.new) }

        object.count = 1
        object.count = 2
        object.count = 3

        c.disconnect()

        XCTAssertEqual(r, [1, 2, 3])
    }

    func test_changes_BasicKVOWithStrings() {
        let object = Fixture()

        var r = [String]()
        let c = object.observable(for: \.name).changes.subscribe { r.append($0.new) }

        object.name = "Alice"
        object.name = "Bob"
        object.name = "Charlie"

        c.disconnect()

        object.name = "Daniel"

        XCTAssertEqual(r, ["Alice", "Bob", "Charlie"])
    }

    func test_changes_BasicKVOWithOptionals() {
        let object = Fixture()

        var r = [String?]()
        let c = object.observable(for: \.optional).changes.subscribe { r.append($0.new) }

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


    func test_changes_DisconnectActuallyDisconnects() {
        let object = Fixture()

        let count = object.observable(for: \.count)

        var r = [Int]()
        let c = count.changes.subscribe { r.append($0.new) }

        object.count = 1

        c.disconnect()

        object.count = 2
        object.count = 3

        XCTAssertEqual(r, [1])
    }

    func test_changes_SourceRetainsObject() {
        var source: AnySource<ValueChange<Int>>? = nil
        weak var weakObject: NSObject? = nil

        do {
            let object = Fixture()
            weakObject = object

            source = object.observable(for: \.count).changes
        }

        XCTAssertNotNil(weakObject)
        source = nil
        XCTAssertNil(weakObject)

        noop(source)
    }

    func test_changes_ConnectionRetainsObject() {
        var c: Connection? = nil
        weak var weakObject: NSObject? = nil

        do {
            let object = Fixture()
            weakObject = object

            c = object.observable(for: \.count).changes.subscribe { _ in }
        }

        XCTAssertNotNil(weakObject)
        c?.disconnect()
        XCTAssertNil(weakObject)
    }

    //MARK: Reentrant observers

    func test_rawKVO_ReentrantUpdates() {
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

    func test_changes_ReentrantUpdates1() {
        // KVO supports reentrant updates, but it performs them synchronously, always sending the most up to date value.
        // Our observable delays sending changes until the transaction is over,
        let object = Fixture()

        let count = object.observable(for: \.count)

        var s = ""
        let c = count.updates.subscribe { update in
            switch update {
            case .beginTransaction:
                s += "(<)"
            case .change(let change):
                s += "(\(change))"
                if count.value > 0 {
                    object.count = count.value - 1
                }
            case .endTransaction:
                s += "(>)"
            }
        }

        object.count = 3

        XCTAssertEqual(object.count, 0)

        // Contrast this with the previous test.
        XCTAssertEqual(s, "(<)(0 -> 3)(3 -> 2)(2 -> 1)(1 -> 0)(>)")

        c.disconnect()
    }

    func test_changes_ReentrantUpdates2() {
        // KVO supports reentrant updates, but it performs them synchronously, always sending the most up to date value.
        let object = Fixture()

        let count = object.observable(for: \.count)

        var s = ""
        let c = count.updates.subscribe { update in
            switch update {
            case .beginTransaction:
                s += "(<)"
            case .change(let change):
                s += "(\(change))"
            case .endTransaction:
                s += "(>)"
                if count.value > 0 {
                    object.count = count.value - 1
                }
            }
        }

        object.count = 3

        XCTAssertEqual(object.count, 0)

        // Contrast this with the previous test.
        XCTAssertEqual(s, "(<)(0 -> 3)(>)(<)(3 -> 2)(>)(<)(2 -> 1)(>)(<)(1 -> 0)(>)")
        
        c.disconnect()
    }
    

    func test_rawKVO_MutuallyReentrantUpdates() {
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


    func test_changes_MutuallyReentrantUpdates() {
        // KVO supports reentrant updates, but it performs them synchronously, always sending the most up to date value.
        // However, our changes source will delay notifications until the end of the transaction.

        let object = Fixture()

        let count = object.observable(for: \.count)

        var s = ""
        let c1 = count.changes.subscribe { c in
            let i = c.new
            s += " (\(c)"
            if i > 0 {
                object.count = i - 1
            }
            s += ")"
        }
        let c2 = count.changes.subscribe { c in
            let i = c.new
            s += " (\(c)"
            if i > 0 {
                object.count = i - 1
            }
            s += ")"
        }

        object.count = 2

        // Contrast this with the previous test.
        XCTAssertEqual(s, " (0 -> 2 (2 -> 1 (1 -> 0))) (0 -> 0)")

        c1.disconnect()
        c2.disconnect()
    }

    func test_updates_WillChangeStartsATransaction() {
        let object = Fixture()

        let count = object.observable(for: \.count)
        let sink = MockValueUpdateSink<Int>(count)

        sink.expecting("begin") {
            object.willChangeValue(forKey: "count")
        }

        sink.expectingNothing {
            object._count += 1
        }

        sink.expecting(["0 -> 1", "end"]) {
            object.didChangeValue(forKey: "count")
        }
        
        sink.disconnect()
    }

    func test_updates_WillChangeStartsATransaction2() {
        let object = Fixture()

        let count = object.observable(for: \.count)
        let sink = MockValueUpdateSink<Int>(count)

        sink.expecting("begin") {
            object.willChangeValue(forKey: "count")
        }

        sink.expectingNothing {
            object._count += 1
        }

        sink.expectingNothing {
            object.willChangeValue(forKey: "count")
        }

        sink.expectingNothing {
            object._count += 1
        }

        sink.expectingNothing() {
            object.didChangeValue(forKey: "count")
        }

        sink.expecting(["0 -> 2", "end"]) {
            object.didChangeValue(forKey: "count")
        }

        sink.disconnect()
    }


    func test_updates_SubscribingAfterWillChange() {
        let object = Fixture()

        object.willChangeValue(forKey: "count")

        let count = object.observable(for: \.count)
        let sink = MockValueUpdateSink<Int>()

        // The change that was pending at the time of subscription isn't reported.
        sink.expectingNothing {
            count.add(sink)
            object._count += 1
            object.didChangeValue(forKey: "count")
        }

        sink.expecting("begin") {
            object.willChangeValue(forKey: "count")
        }

        sink.expectingNothing {
            object._count += 1
        }

        sink.expecting(["1 -> 2", "end"]) {
            object.didChangeValue(forKey: "count")
        }

        count.remove(sink)
    }

    func test_updates_UnsubscribingBeforeDidChange() {
        let object = Fixture()

        let count = object.observable(for: \.count)
        let sink = MockValueUpdateSink<Int>()

        count.add(sink)

        sink.expecting("begin") {
            object.willChangeValue(forKey: "count")
        }

        sink.expectingNothing {
            object._count += 1
        }

        // We get "end" due to TransactionState's bracketing, but the change itself isn't reported.
        sink.expecting("end") {
            count.remove(sink)
        }

        sink.expectingNothing {
            object.didChangeValue(forKey: "count")
        }

        withExtendedLifetime(count) {}
    }

    func test_updatable_IntegerKey() {
        let object = Fixture()

        let count = object.updatable(for: \.count)
        let sink = MockValueUpdateSink<Int>(count)

        sink.expecting(["begin", "0 -> 1", "end"]) {
            count.value = 1
        }

        // Our KVO-adaptor updatables behave as if they were buffered
        sink.expecting("begin") {
            count.apply(.beginTransaction)
        }
        sink.expectingNothing {
            count.apply(ValueChange(from: 1, to: 2))
            count.apply(ValueChange(from: 2, to: 3))
        }
        sink.expecting(["1 -> 3", "end"]) {
            count.apply(.endTransaction)
        }

        // will/didChange gets translated into begin/endTransaction
        sink.expecting("begin") {
            object.willChangeValue(forKey: "count")
        }
        sink.expectingNothing {
            object._count = 4
        }
        sink.expecting(["3 -> 4", "end"]) {
            object.didChangeValue(forKey: "count")
        }

        sink.disconnect()
    }

    func test_updatable_OptionalKey() {
        let object = Fixture()

        let updatable = object.updatable(for: \.optional)
        let sink = MockValueUpdateSink<String?>(updatable)

        sink.expecting(["begin", "nil -> Optional(\"foo\")", "end"]) {
            updatable.value = "foo"
        }

        // Our KVO-adaptor updatables behave as if they were buffered
        sink.expecting("begin") {
            updatable.apply(.beginTransaction)
        }
        sink.expectingNothing {
            updatable.apply(ValueChange(from: "foo", to: nil))
            updatable.apply(ValueChange(from: nil, to: "bar"))
        }
        sink.expecting(["Optional(\"foo\") -> Optional(\"bar\")", "end"]) {
            updatable.apply(.endTransaction)
        }

        sink.disconnect()
    }

    func test_observable_keyPath() {
        let object = Fixture()
        let next = Fixture()
        object.next = next

//        let count = object.observable(for: \.next?.count)
//
//        let sink = MockValueUpdateSink<Int>(count)
//
//        sink.expecting(["begin", "0 -> 1", "end"]) {
//            next.count = 1
//        }
//
//        sink.expecting(["begin", "1 -> 2", "end"]) {
//            object.setValue(2, forKeyPath: "next.count")
//        }
//
//        sink.expecting("begin") {
//            next.willChangeValue(forKey: "count")
//        }
//        sink.expectingNothing {
//            next._count = 3
//        }
//        sink.expecting(["2 -> 3", "end"]) {
//            next.didChangeValue(forKey: "count")
//        }
//
//        let next2 = Fixture()
//        next2.count = 4
//
//        sink.expecting("begin") {
//            object.willChangeValue(forKey: "next")
//        }
//        sink.expectingNothing {
//            object._next = next2
//        }
//        sink.expecting(["3 -> 4", "end"]) {
//            object.didChangeValue(forKey: "next")
//        }
//
//        sink.disconnect()
    }

    func test_observable_keyPathNestedTransactions() {
//        let object = Fixture()
//        let next = Fixture()
//        next.count = 1
//
//        object.next = next
//
//        let next2 = Fixture()
//        next2.count = 2
//
//        let count = object.observable(for: \.next?.count)
//
//        let sink = MockValueUpdateSink<Int>(count)
//
//        sink.expecting("begin") {
//            object.willChangeValue(forKey: "next")
//        }
//        sink.expectingNothing {
//            next2.willChangeValue(forKey: "count")
//            object._next = next2
//            next2._count = 3
//        }
//
//        sink.expecting(["1 -> 3", "end"]) {
//            object.didChangeValue(forKey: "next")
//        }
//        sink.expectingNothing {
//            next2._count = 4 // Unfortunately, this change never gets reported.
//            next2.didChangeValue(forKey: "count")
//        }
//
//        sink.disconnect()
    }


}
