//
//  ObservableSetTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-10.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

private class TestObservableSet<Element: Hashable>: ObservableSetType {

    var signal = Signal<SetChange<Element>>()
    var _value: Set<Element>

    init(_ value: Set<Element>) {
        self._value = value
    }

    var value: Set<Element> {
        get {
            return _value
        }
        set {
            let old = _value
            _value = newValue
            signal.send(.init(from: old, to: newValue))
        }
    }
    var changes: Source<SetChange<Element>> {
        return signal.source
    }

    func insert(_ member: Element) {
        if _value.contains(member) { return }
        _value.insert(member)
        signal.send(SetChange(removed: [], inserted: [member]))
    }

    func remove(_ member: Element) {
        if !_value.contains(member) { return }
        _value.remove(member)
        signal.send(SetChange(removed: [member], inserted: []))
    }

    func apply(_ change: SetChange<Element>) {
        if change.isEmpty { return }
        _value.subtract(change.removed)
        _value.formUnion(change.inserted)
        signal.send(change)
    }
}

private class TestUpdatableSet<Element: Hashable>: TestObservableSet<Element>, UpdatableSetType {

}

class ObservableSetTypeTests: XCTestCase {
    func testDefaultImplementations() {
        let test = TestObservableSet([1, 2, 3])
        XCTAssertFalse(test.isBuffered)
        XCTAssertEqual(test.count, 3)
        XCTAssertTrue(test.contains(2))
        XCTAssertTrue(test.contains(2))
        XCTAssertTrue(test.isSubset(of: [1, 2, 3, 4]))
        XCTAssertFalse(test.isSubset(of: [1, 3, 4]))
        XCTAssertTrue(test.isSuperset(of: [1, 2]))
        XCTAssertFalse(test.isSuperset(of: [0, 1]))

        let t = test.observableSet
        XCTAssertFalse(t.isBuffered)
        XCTAssertEqual(t.count, 3)
        XCTAssertTrue(t.contains(2))
        XCTAssertTrue(t.contains(2))
        XCTAssertTrue(t.isSubset(of: [1, 2, 3, 4]))
        XCTAssertFalse(t.isSubset(of: [1, 3, 4]))
        XCTAssertTrue(t.isSuperset(of: [1, 2]))
        XCTAssertFalse(t.isSuperset(of: [0, 1]))
    }


    func testConversionToObservableValue() {
        let test = TestObservableSet([1, 2, 3])

        let o1 = test.observable
        XCTAssertEqual(o1.value, [1, 2, 3])

        let m1 = MockValueObserver(o1)
        m1.expecting(.init(from: [1, 2, 3], to: [1, 3])) {
            test.remove(2)
        }
        XCTAssertEqual(o1.value, [1, 3])

        let o2 = test.observableSet.observable
        XCTAssertEqual(o2.value, [1, 3])

        let m2 = MockValueObserver(o2)
        m2.expecting(.init(from: [1, 3], to: [1, 2, 3])) {
            test.insert(2)
        }
        XCTAssertEqual(o2.value, [1, 2, 3])
    }

    func testObservableCount() {
        let test = TestObservableSet([1, 2, 3])

        let count = test.observableCount
        XCTAssertEqual(count.value, 3)

        let mock = MockValueObserver(count)
        mock.expecting(.init(from: 3, to: 4)) {
            test.insert(10)
        }
        XCTAssertEqual(count.value, 4)
        mock.expecting(.init(from: 4, to: 2)) {
            test.apply(.init(removed: [2, 3], inserted: []))
        }
        XCTAssertEqual(count.value, 2)
    }

    func testObservableCountViaTypeLiftedSet() {
        let test = TestObservableSet([1, 2, 3])

        let count = test.observableSet.observableCount
        XCTAssertEqual(count.value, 3)

        let mock = MockValueObserver(count)
        mock.expecting(.init(from: 3, to: 4)) {
            test.insert(10)
        }
        XCTAssertEqual(count.value, 4)
        mock.expecting(.init(from: 4, to: 2)) {
            test.apply(.init(removed: [2, 3], inserted: []))
        }
        XCTAssertEqual(count.value, 2)
    }

    func testObservableSetConstant() {
        let constant = ObservableSet.constant([1, 2, 3])

        XCTAssertTrue(constant.isBuffered)
        XCTAssertEqual(constant.count, 3)
        XCTAssertEqual(constant.value, [1, 2, 3])
        XCTAssertTrue(constant.contains(2))
        XCTAssertFalse(constant.contains(0))
        XCTAssertTrue(constant.isSubset(of: [1, 2, 3, 4]))
        XCTAssertFalse(constant.isSubset(of: [1, 3, 4]))
        XCTAssertTrue(constant.isSuperset(of: [1, 2]))
        XCTAssertFalse(constant.isSuperset(of: [0, 2]))

        let mock = MockSetObserver(constant)
        mock.expectingNoChange {
            // Well whatever
        }

        let observable = constant.observable
        XCTAssertEqual(observable.value, [1, 2, 3])

        let observableCount = constant.observableCount
        XCTAssertEqual(observableCount.value, 3)
    }
}

