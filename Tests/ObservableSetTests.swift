//
//  ObservableSetTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-10.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import GlueKit

private class TestObservableSet<Element: Hashable>: ObservableSetBase<Element> {
    var signal = Signal<SetChange<Element>>()
    var _value: Set<Element>

    init(_ value: Set<Element>) {
        self._value = value
    }

    override var value: Set<Element> { return _value }
    override var changes: Source<SetChange<Element>> { return signal.source }

    func apply(_ change: SetChange<Element>) {
        if change.isEmpty { return }
        _value.subtract(change.removed)
        _value.formUnion(change.inserted)
        signal.send(change)
    }
}

private class TestObservableSet2<Element: Hashable>: ObservableSetType {
    var signal = Signal<SetChange<Element>>()
    var _value: Set<Element>

    init(_ value: Set<Element>) {
        self._value = value
    }

    var value: Set<Element> { return _value }
    var changes: Source<SetChange<Element>> { return signal.source }

    func apply(_ change: SetChange<Element>) {
        if change.isEmpty { return }
        _value.subtract(change.removed)
        _value.formUnion(change.inserted)
        signal.send(change)
    }
}


private class TestUpdatableSet<Element: Hashable>: UpdatableSetBase<Element> {
    var signal = Signal<SetChange<Element>>()
    var _value: Set<Element>

    init(_ value: Set<Element>) {
        self._value = value
    }

    override var value: Set<Element> {
        get { return _value }
        set { self.apply(SetChange(removed: _value, inserted: newValue)) }
    }
    override var changes: Source<SetChange<Element>> { return signal.source }

    override func apply(_ change: SetChange<Element>) {
        if change.isEmpty { return }
        _value.subtract(change.removed)
        _value.formUnion(change.inserted)
        signal.send(change)
    }
}

private class TestUpdatableSet2<Element: Hashable>: UpdatableSetType {
    var signal = Signal<SetChange<Element>>()
    var _value: Set<Element>

    init(_ value: Set<Element>) {
        self._value = value
    }

    var value: Set<Element> {
        get { return _value }
        set { self.apply(SetChange(removed: _value, inserted: newValue)) }
    }
    var changes: Source<SetChange<Element>> { return signal.source }

    func apply(_ change: SetChange<Element>) {
        if change.isEmpty { return }
        _value.subtract(change.removed)
        _value.formUnion(change.inserted)
        signal.send(change)
    }
}


class ObservableSetTypeTests: XCTestCase {
    func testDefaultImplementations() {
        func check<T, S: ObservableSetType>(isBuffered: Bool = false, make: (Set<S.Element>) -> T, convert: (T) -> S, apply: @escaping (T, SetChange<S.Element>) -> Void) where S.Element == Int {
            let t = make([1, 2, 3])
            let test = convert(t)
            XCTAssertEqual(test.value, [1, 2, 3])
            XCTAssertEqual(test.isBuffered, isBuffered)
            XCTAssertEqual(test.count, 3)
            XCTAssertFalse(test.isEmpty)
            XCTAssertTrue(test.contains(2))
            XCTAssertFalse(test.contains(4))
            XCTAssertTrue(test.isSubset(of: [1, 2, 3, 4]))
            XCTAssertFalse(test.isSubset(of: [1, 3, 4]))
            XCTAssertTrue(test.isSuperset(of: [1, 2]))
            XCTAssertFalse(test.isSuperset(of: [0, 1]))

            let observableValue = test.observable
            let observableCount = test.observableCount

            XCTAssertEqual(observableValue.value, [1, 2, 3])
            XCTAssertEqual(observableCount.value, 3)

            let mock = MockSetObserver(test)
            let vmock = MockValueObserver(observableValue)
            let cmock = MockValueObserver(observableCount)

            mock.expecting("[]/[4]") {
                vmock.expecting(.init(from: [1, 2, 3], to: [1, 2, 3, 4])) {
                    cmock.expecting(.init(from: 3, to: 4)) {
                        apply(t, SetChange<Int>(inserted: [4]))
                    }
                }
            }
            XCTAssertTrue(test.contains(4))
            XCTAssertEqual(test.value, [1, 2, 3, 4])

            mock.expectingNoChange {
                vmock.expectingNoChange {
                    cmock.expectingNoChange {
                        apply(t, SetChange<Int>())
                    }
                }
            }
            XCTAssertEqual(test.value, [1, 2, 3, 4])
        }

        check(make: { TestObservableSet($0) }, convert: { $0 }, apply: { $0.apply($1) })
        check(make: { TestObservableSet($0) }, convert: { $0.observableSet }, apply: { $0.apply($1) })

        check(make: { TestObservableSet2($0) }, convert: { $0 }, apply: { $0.apply($1) })
        check(make: { TestObservableSet2($0) }, convert: { $0.observableSet }, apply: { $0.apply($1) })

        check(make: { TestUpdatableSet($0) }, convert: { $0 }, apply: { $0.apply($1) })
        check(make: { TestUpdatableSet($0) }, convert: { $0.updatableSet }, apply: { $0.apply($1) })
        check(make: { TestUpdatableSet($0) }, convert: { $0.observableSet }, apply: { $0.apply($1) })
        check(make: { TestUpdatableSet($0) }, convert: { $0.updatableSet.observableSet }, apply: { $0.apply($1) })

        check(make: { TestUpdatableSet2($0) }, convert: { $0 }, apply: { $0.apply($1) })
        check(make: { TestUpdatableSet2($0) }, convert: { $0.updatableSet }, apply: { $0.apply($1) })
        check(make: { TestUpdatableSet2($0) }, convert: { $0.observableSet }, apply: { $0.apply($1) })
        check(make: { TestUpdatableSet2($0) }, convert: { $0.updatableSet.observableSet }, apply: { $0.apply($1) })

        check(isBuffered: true, make: { SetVariable<Int>($0) }, convert: { $0 }, apply: { $0.apply($1) })

        class T {
            let foo: TestUpdatableSet<Int>
            init(_ v: Set<Int>) { self.foo = .init(v) }
        }
        check(make: { Variable<T>(T($0)).map { $0.foo } }, convert: { $0 }, apply: { $0.apply($1) })

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
            XCTAssertEqual(test.value, [10, 20, 30])

            mock.expecting("[10, 20, 30]/[]") {
                test.removeAll()
            }
            XCTAssertEqual(test.value, [])
            mock.expectingNoChange {
                test.removeAll()
            }
            XCTAssertEqual(test.value, [])

            mock.expecting("[]/[1, 2, 3]") {
                test.formUnion([1, 2, 3])
            }
            XCTAssertEqual(test.value, [1, 2, 3])
            mock.expecting("[3]/[]") {
                test.formIntersection([0, 1, 2, 6])
            }
            XCTAssertEqual(test.value, [1, 2])
            mock.expecting("[2]/[3, 4]") {
                test.formSymmetricDifference([2, 3, 4])
            }
            XCTAssertEqual(test.value, [1, 3, 4])
            mock.expecting("[1, 4]/[]") {
                test.subtract([1, 4, 5])
            }
            XCTAssertEqual(test.value, [3])
        }

        check { TestUpdatableSet<Int>($0) }
        check { TestUpdatableSet<Int>($0).updatableSet }
        check { TestUpdatableSet<Int>($0).updatableSet.updatableSet }
        check { TestUpdatableSet2<Int>($0) }
        check { TestUpdatableSet2<Int>($0).updatableSet }
        check { TestUpdatableSet2<Int>($0).updatableSet.updatableSet }
        check { SetVariable<Int>($0) }
        check { SetVariable<Int>($0).updatableSet }

        class T {
            let foo: TestUpdatableSet<Int>
            init(_ v: Set<Int>) { self.foo = .init(v) }
        }
        check { Variable<T>(T($0)).map { $0.foo } }
    }

    func testUpdatableDefaultImplementations_NoObservers() {
        func check<U: UpdatableSetType>(_ make: (Set<Int>) -> U) where U.Element == Int {
            let test = make([1, 2, 3])

            XCTAssertEqual(test.value, [1, 2, 3])

            test.insert(4)
            XCTAssertEqual(test.value, [1, 2, 3, 4])
            test.insert(2)
            XCTAssertEqual(test.value, [1, 2, 3, 4])
            test.remove(2)
            XCTAssertEqual(test.value, [1, 3, 4])
            test.remove(2)
            test.modify { v in
                v.insert(0)
                v.remove(3)
            }
            XCTAssertEqual(test.value, [0, 1, 4])
            test.value = [10, 20, 30]
            XCTAssertEqual(test.value, [10, 20, 30])
            test.removeAll()
            XCTAssertEqual(test.value, [])
            test.removeAll()
            XCTAssertEqual(test.value, [])
            test.formUnion([1, 2, 3])
            XCTAssertEqual(test.value, [1, 2, 3])
            test.formIntersection([0, 1, 2, 6])
            XCTAssertEqual(test.value, [1, 2])
            test.formSymmetricDifference([2, 3, 4])
            XCTAssertEqual(test.value, [1, 3, 4])
            test.subtract([1, 4, 5])
            XCTAssertEqual(test.value, [3])
        }

        check { TestUpdatableSet<Int>($0) }
        check { TestUpdatableSet<Int>($0).updatableSet }
        check { TestUpdatableSet<Int>($0).updatableSet.updatableSet }
        check { TestUpdatableSet2<Int>($0) }
        check { TestUpdatableSet2<Int>($0).updatableSet }
        check { TestUpdatableSet2<Int>($0).updatableSet.updatableSet }
        check { SetVariable<Int>($0) }
        check { SetVariable<Int>($0).updatableSet }

        class T {
            let foo: TestUpdatableSet<Int>
            init(_ v: Set<Int>) { self.foo = .init(v) }
        }
        check { Variable<T>(T($0)).map { $0.foo } }
    }

}

