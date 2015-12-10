//
//  ObservableTransformationTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-08.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

private class TestObservable: ObservableType {
    var _value: Int = 0
    var _signal = Signal<Int>()

    var value: Int {
        get {
            return _value
        }
        set {
            _value = newValue
            _signal.send(newValue)
        }
    }

    var futureValues: Source<Int> { return _signal.source }
}

private class TestUpdatable: UpdatableType {
    var _value: Int = 0
    var _signal = Signal<Int>()

    var value: Int {
        get {
            return _value
        }
        set {
            _value = newValue
            _signal.send(newValue)
        }
    }

    var futureValues: Source<Int> { return _signal.source }
}


class ObservableTransformationTests: XCTestCase {

    func testMap_Works() {
        let observable = TestObservable()

        let mapped = observable.map { "\($0)" }

        XCTAssertEqual(mapped.value, "0")

        observable.value = 1
        XCTAssertEqual(mapped.value, "1") // mapped observable reflects upstream's changes

        var r = [String]()
        let c = mapped.values.connect { r.append($0) }

        observable.value = 2
        observable.value = 3

        c.disconnect()

        observable.value = 4

        XCTAssertEqual(r, ["1", "2", "3"])
    }

    func testMap_RetainsItsInput() {
        weak var test: TestObservable? = nil
        var mapped: Observable<String>? = nil
        do {
            let o = TestObservable()
            test = o
            mapped = o.map { "\($0)" }
            o.value = 42
        }
        XCTAssertNotNil(test)
        XCTAssertEqual(mapped?.value, "42")
    }

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

        d.value = 42
        XCTAssertEqual(test.value, 42)
    }

    func testCombine_Works() {
        let a = TestObservable()
        let b = TestObservable()

        a.value = 1
        b.value = 2

        let combined = a.combine(b) { a, b in "\(a) - \(b)" }

        var r = [String]()
        let c = combined.values.connect { r.append($0) }
        XCTAssertEqual(r, ["1 - 2"])
        a.value = 3
        XCTAssertEqual(r, ["1 - 2", "3 - 2"])
        b.value = 4
        XCTAssertEqual(r, ["1 - 2", "3 - 2", "3 - 4"])
        a.value = 5
        a.value = 5
        b.value = 6
        XCTAssertEqual(r, ["1 - 2", "3 - 2", "3 - 4", "5 - 4", "5 - 4", "5 - 6"])
        c.disconnect()
    }

    func testCombineDistinct_WithNestedUpdates() {
        let a = TestObservable()
        let b = TestObservable()
        let combined = a.combine(b) { a, b in (a, b) }.distinct { old, new in old.0 == new.0 && old.1 == new.1 }

        a.value = 3
        b.value = 2

        var r = ""
        let c = combined.values.connect { av, bv in
            r += " (\(av)-\(bv)"
            if av > 0 {
                a.value = av - 1
            }
            else if bv > 0 {
                b.value = bv - 1
            }
            r += ")"
        }

        XCTAssertEqual(r, " (3-2) (2-2) (1-2) (0-2) (0-1) (0-0)")
        c.disconnect()
    }

    func testEquatableOperators() {
        let a = TestObservable()
        let b = TestObservable()

        let eq = (a.observable == b.observable)
        let ne = (a.observable != b.observable)

        XCTAssertTrue(eq.value)
        XCTAssertFalse(ne.value)

        a.value = 1

        XCTAssertFalse(eq.value)
        XCTAssertTrue(ne.value)
    }

    func testComparableOperators() {
        let a = TestObservable()
        let b = TestObservable()

        let lt = (a.observable < b.observable)
        let gt = (a.observable > b.observable)
        let le = (a.observable <= b.observable)
        let ge = (a.observable >= b.observable)
        let mi = min(a.observable, b.observable)
        let ma = max(a.observable, b.observable)

        XCTAssertFalse(lt.value)
        XCTAssertFalse(gt.value)
        XCTAssertTrue(le.value)
        XCTAssertTrue(ge.value)
        XCTAssertEqual(mi.value, 0)
        XCTAssertEqual(ma.value, 0)

        a.value = 1

        XCTAssertFalse(lt.value)
        XCTAssertTrue(gt.value)
        XCTAssertFalse(le.value)
        XCTAssertTrue(ge.value)
        XCTAssertEqual(mi.value, 0)
        XCTAssertEqual(ma.value, 1)

        b.value = 2

        XCTAssertTrue(lt.value)
        XCTAssertFalse(gt.value)
        XCTAssertTrue(le.value)
        XCTAssertFalse(ge.value)
        XCTAssertEqual(mi.value, 1)
        XCTAssertEqual(ma.value, 2)

        a.value = 2

        XCTAssertFalse(lt.value)
        XCTAssertFalse(gt.value)
        XCTAssertTrue(le.value)
        XCTAssertTrue(ge.value)
        XCTAssertEqual(mi.value, 2)
        XCTAssertEqual(ma.value, 2)
    }

    func testBooleanOperators() {
        let a = TestUpdatable()
        let b = TestUpdatable()
        let c = TestUpdatable()

        let bIsBetweenAAndC = a.observable < b.observable && b.observable < c.observable
        let bIsNotBetweenAAndC = !bIsBetweenAAndC
        let aIsNotTheGreatest = a.observable < b.observable || a.observable < c.observable

        XCTAssertFalse(bIsBetweenAAndC.value)
        XCTAssertTrue(bIsNotBetweenAAndC.value)
        XCTAssertFalse(aIsNotTheGreatest.value)

        a.value = 1

        XCTAssertFalse(bIsBetweenAAndC.value)
        XCTAssertTrue(bIsNotBetweenAAndC.value)
        XCTAssertFalse(aIsNotTheGreatest.value)

        b.value = 2

        XCTAssertFalse(bIsBetweenAAndC.value)
        XCTAssertTrue(bIsNotBetweenAAndC.value)
        XCTAssertTrue(aIsNotTheGreatest.value)

        c.value = 3

        XCTAssertTrue(bIsBetweenAAndC.value)
        XCTAssertFalse(bIsNotBetweenAAndC.value)
        XCTAssertTrue(aIsNotTheGreatest.value)
    }

    func testArithmeticOperators() {
        let a = TestUpdatable()
        let b = TestUpdatable()
        let c = TestUpdatable()

        let expression = a.observable % Observable.constant(10) + b.observable * c.observable / (a.observable + Observable.constant(1)) - c.observable

        var r = [Int]()
        let connection = expression.values.connect { r.append($0) }

        XCTAssertEqual(r, [0])
        r = []

        a.value = 1

        // The observable 'a' occurs twice in the expression above, so the expression will be evaluated twice.
        // The first evaluation will only apply the new value to one of the sources.
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r.last, 1)

        r = []

        b.value = 2

        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.last, 1)
        r = []

        c.value = 3

        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r.last, 1 + 2 * 3 / 2 - 3)
        r = []

        a.value = 15

        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r.last, 5 + 2 * 3 / 16 - 3)
        r = []


        connection.disconnect()
    }

}

