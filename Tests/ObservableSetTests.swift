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
        func check<S: ObservableSetType>(isBuffered: Bool = false, make: (Set<S.Element>) -> S, apply: @escaping (S, SetChange<S.Element>) -> Void) where S.Element == Int {
            let test = make([1, 2, 3])
            XCTAssertEqual(test.value, [1, 2, 3])
            XCTAssertEqual(test.isBuffered, isBuffered)
            XCTAssertEqual(test.count, 3)
            XCTAssertTrue(test.contains(2))
            XCTAssertFalse(test.contains(4))
            XCTAssertTrue(test.isSubset(of: [1, 2, 3, 4]))
            XCTAssertFalse(test.isSubset(of: [1, 3, 4]))
            XCTAssertTrue(test.isSuperset(of: [1, 2]))
            XCTAssertFalse(test.isSuperset(of: [0, 1]))

            let mock = MockSetObserver(test)
            mock.expecting("[]/[4]") {
                apply(test, SetChange<Int>(inserted: [4]))
            }
            XCTAssertTrue(test.contains(4))
            XCTAssertEqual(test.value, [1, 2, 3, 4])

            mock.expectingNoChange {
                apply(test, SetChange<Int>())
            }
            XCTAssertEqual(test.value, [1, 2, 3, 4])
        }

        check(make: { TestObservableSet($0) }, apply: { $0.apply($1) })

        var t1: TestObservableSet<Int>? = nil
        check(make: { v -> ObservableSet<Int> in t1 = TestObservableSet(v); return t1!.observableSet },
              apply: { t1!.apply($1) }) // Yuck

        check(make: { TestUpdatableSet($0) }, apply: { $0.apply($1) })
        check(make: { TestUpdatableSet($0).updatableSet }, apply: { $0.apply($1) })

        var t2: TestUpdatableSet<Int>? = nil
        check(make: { v -> ObservableSet<Int> in t2 = TestUpdatableSet(v); return t2!.observableSet },
              apply: { t2!.apply($1) }) // Yuck

        var t3: TestUpdatableSet<Int>? = nil
        check(make: { v -> ObservableSet<Int> in t3 = TestUpdatableSet(v); return t3!.updatableSet.observableSet },
              apply: { t3!.apply($1) }) // Yuck

        check(isBuffered: true, make: { SetVariable<Int>($0) }, apply: { $0.apply($1) })
    }


    func testConversionToObservableValue() {
        func check<S: ObservableSetType>(make: (Set<S.Element>) -> S, apply: @escaping (S, SetChange<S.Element>) -> Void) where S.Element == Int {
            let test = make([1, 2, 3])
            let o1 = test.observable
            XCTAssertEqual(o1.value, [1, 2, 3])
            let m1 = MockValueObserver(o1)
            m1.expecting(.init(from: [1, 2, 3], to: [1, 3])) {
                apply(test, SetChange(removed: [2]))
            }
            XCTAssertEqual(o1.value, [1, 3])
        }

        check(make: { TestObservableSet($0) }, apply: { $0.apply($1) })

        var t: TestObservableSet<Int>? = nil
        check(make: { v -> ObservableSet<Int> in t = TestObservableSet(v); return t!.observableSet },
              apply: { t!.apply($1) }) // Yuck

        check(make: { TestUpdatableSet($0) }, apply: { $0.apply($1) })
        check(make: { TestUpdatableSet($0).updatableSet }, apply: { $0.apply($1) })
        check(make: { SetVariable<Int>($0) }, apply: { $0.apply($1) })
    }

    func testObservableCount() {
        func check<S: ObservableSetType>(make: (Set<S.Element>) -> S, apply: @escaping (S, SetChange<S.Element>) -> Void) where S.Element == Int {
            let test = make([1, 2, 3])

            let count = test.observableCount
            XCTAssertEqual(count.value, 3)

            let mock = MockValueObserver(count)
            mock.expecting(.init(from: 3, to: 4)) {
                apply(test, SetChange(inserted: [10]))
            }
            XCTAssertEqual(count.value, 4)
            mock.expecting(.init(from: 4, to: 2)) {
                apply(test, .init(removed: [2, 3]))
            }
            XCTAssertEqual(count.value, 2)
        }

        check(make: { TestObservableSet($0) }, apply: { $0.apply($1) })

        var t: TestObservableSet<Int>? = nil
        check(make: { v -> ObservableSet<Int> in t = TestObservableSet(v); return t!.observableSet },
              apply: { t!.apply($1) }) // Yuck

        check(make: { TestUpdatableSet($0) }, apply: { $0.apply($1) })
        check(make: { TestUpdatableSet($0).updatableSet }, apply: { $0.apply($1) })
        check(make: { SetVariable<Int>($0) }, apply: { $0.apply($1) })
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

    func testUpdatableDefaultImplementations() {
        func check<U: UpdatableSetType>(_ make: (Set<Int>) -> U) where U.Element == Int {
            let test = make([1, 2, 3])

            XCTAssertEqual(test.value, [1, 2, 3])

            let mock = MockSetObserver(test)

            mock.expecting("[]/[4]") {
                test.insert(4)
            }
            XCTAssertEqual(test.value, [1, 2, 3, 4])

            mock.expectingNoChange {
                test.insert(2)
            }
            XCTAssertEqual(test.value, [1, 2, 3, 4])

            mock.expecting("[2]/[]") {
                test.remove(2)
            }
            XCTAssertEqual(test.value, [1, 3, 4])

            mock.expectingNoChange {
                test.remove(2)
            }

            mock.expecting("[3]/[0]") {
                test.modify { v in
                    v.insert(0)
                    v.remove(3)
                }
            }
            XCTAssertEqual(test.value, [0, 1, 4])

            mock.expecting("[0, 1, 4]/[10, 20, 30]") {
                test.value = [10, 20, 30]
            }
        }

        check { TestUpdatableSet<Int>($0) }
        check { TestUpdatableSet<Int>($0).updatableSet }
        check { TestUpdatableSet<Int>($0).updatableSet.updatableSet }
        check { SetVariable<Int>($0) }
    }
}

