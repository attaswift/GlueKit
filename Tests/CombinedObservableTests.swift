//
//  CombinedObservableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
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

class CombinedObservableTests: XCTestCase {
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

        let e1 = a.observable % Observable.constant(10)
        let e2 = b.observable * c.observable / (a.observable + Observable.constant(1))
        let expression = e1 + e2 - c.observable

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

