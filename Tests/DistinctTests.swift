//
//  DistinctTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-08.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

private class TestObservable: ObservableValueType {
    var _signal = Signal<SimpleChange<Int>>()

    var value: Int = 0{
        didSet {
            _signal.send(.init(from: oldValue, to: value))
        }
    }

    var changes: Source<SimpleChange<Int>> { return _signal.source }
}

private class TestUpdatable: UpdatableValueType {
    var _signal = Signal<SimpleChange<Int>>()

    var value: Int = 0 {
        didSet {
            _signal.send(.init(from: oldValue, to: value))
        }
    }

    var changes: Source<SimpleChange<Int>> { return _signal.source }
}


class DistinctTests: XCTestCase {
    func testDistinct_DefaultEqualityTestOnValues() {
        let test = TestObservable()
        var r = [Int]()
        let c = test.distinct().values.connect { i in r.append(i) }

        test.value = 0
        test.value = 1
        test.value = 1
        test.value = 1
        test.value = 2

        XCTAssertEqual(r, [0, 1, 2])

        c.disconnect()
    }

    func testDistinct_DefaultEqualityTestOnFutureValues() {
        let test = TestObservable()
        var r = [Int]()
        let c = test.distinct().futureValues.connect { i in r.append(i) }

        test.value = 0 // This will be not sent to the future source.
        test.value = 1
        test.value = 1
        test.value = 1
        test.value = 2

        XCTAssertEqual(r, [1, 2])
        c.disconnect()
    }

    func testDistinct_CustomEqualityTest() {
        let test = TestObservable()

        // This is a really stupid equality test: 1 is never equal to anything, while everything else is the same.
        // This will only let through changes from/to a 1 value.
        let distinctTest = test.distinct { a, b in a != 1 && b != 1 }

        var defaultValues = [Int]()
        let defaultConnection = distinctTest.values.connect { i in defaultValues.append(i) }

        var futureValues = [Int]()
        let futureConnection = distinctTest.futureValues.connect { i in futureValues.append(i) }

        test.value = 0
        test.value = 1
        test.value = 1
        test.value = 1
        test.value = 2
        test.value = 2
        test.value = 2
        test.value = 3

        XCTAssertEqual(defaultValues, [0, 1, 1, 1, 2])
        XCTAssertEqual(futureValues, [1, 1, 1, 2])
        defaultConnection.disconnect()
        futureConnection.disconnect()
    }

    func testDistinct_IsUpdatableWhenCalledOnUpdatables() {
        let test = TestUpdatable()

        let d = test.distinct()

        XCTAssertEqual(d.value, 0)

        let mock = MockValueObserver(d)

        mock.expecting(.init(from: 0, to: 42)) {
            d.value = 42
        }
        XCTAssertEqual(d.value, 42)
        XCTAssertEqual(test.value, 42)
    }
}

