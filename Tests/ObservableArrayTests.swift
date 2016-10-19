//
//  ObservableArrayTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-10.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import GlueKit

private class TestObservableArray<Element>: ObservableArrayType {
    var _state = TransactionState<ArrayChange<Element>>()
    var _value: [Element]

    init(_ value: [Element]) {
        self._value = value
    }

    var count: Int {
        return _value.count
    }

    subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        return _value[bounds]
    }

    var updates: Source<ArrayUpdate<Element>> {
        return _state.source(retaining: self)
    }

    func begin() {
        _state.begin()
    }

    func end() {
        _state.end()
    }

    func apply(_ change: ArrayChange<Element>) {
        if change.isEmpty { return }
        _state.begin()
        _value.apply(change)
        _state.send(change)
        _state.end()
    }
}

private class TestUpdatableArray<Element>: TestObservableArray<Element>, UpdatableArrayType {
    var value: [Element] {
        get { return super.value }
        set { self.apply(ArrayChange(from: value, to: newValue)) }
    }

    override subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        get { return _value[bounds] }
        set { self.apply(ArrayChange(initialCount: count, modification: .replaceSlice(Array(self[bounds]), at: bounds.lowerBound, with: Array(newValue)))) }
    }

    subscript(index: Int) -> Element {
        get { return _value[index] }
        set { self.apply(ArrayChange(initialCount: count, modification: .replace(self[index], at: index, with: newValue))) }
    }

    func batchUpdate(_ body: () -> Void) {
        _state.begin()
        body()
        _state.end()
    }
}

class ObservableArrayTests: XCTestCase {
    func testDefaultImplementations() {
        func check<T, A: ObservableArrayType>(isBuffered: Bool = false, make: ([Int]) -> T, convert: (T) -> A, apply: @escaping (T, ArrayChange<Int>) -> Void) where A.Element == Int, A.Change == ArrayChange<Int> {
            let t = make([1, 2, 3])
            let test = convert(t)

            XCTAssertEqual(test.isBuffered, isBuffered)
            XCTAssertEqual(test.value, [1, 2, 3])
            XCTAssertEqual(test.count, 3)
            XCTAssertEqual(test[0], 1)
            XCTAssertEqual(test[1], 2)
            XCTAssertEqual(test[2], 3)
            XCTAssertFalse(test.isEmpty)
            XCTAssertEqual(test.first, 1)
            XCTAssertEqual(test.last, 3)

            let observable = test.observable
            let observableCount = test.observableCount

            XCTAssertEqual(observable.value, [1, 2, 3])
            XCTAssertEqual(observableCount.value, 3)

            let mock = MockArrayObserver(test)
            let valueMock = MockValueObserver(observable.map { "\($0)" }) // map is to convert array into something equatable
            let countMock = MockValueObserver(observableCount)

            mock.expecting(3, .insert(4, at: 2)) {
                valueMock.expecting(.init(from: "[1, 2, 3]", to: "[1, 2, 4, 3]")) {
                    countMock.expecting(.init(from: 3, to: 4)) {
                        apply(t, ArrayChange<Int>(initialCount: 3, modification: .insert(4, at: 2)))
                    }
                }
            }
            XCTAssertEqual(test.value, [1, 2, 4, 3])
            XCTAssertEqual(observable.value, [1, 2, 4, 3])
            XCTAssertEqual(observableCount.value, 4)

            mock.expecting(4, .replaceSlice([1, 2, 4, 4], at: 0, with: [])) {
                valueMock.expecting(.init(from: "[1, 2, 4, 3]", to: "[]")) {
                    countMock.expecting(.init(from: 4, to: 0)) {
                        apply(t, ArrayChange<Int>(initialCount: 4, modification: .replaceSlice([1, 2, 4, 4], at: 0, with: [])))
                    }
                }
            }
            XCTAssertEqual(test.value, [])
            XCTAssertEqual(observable.value, [])
            XCTAssertEqual(observableCount.value, 0)

            XCTAssertEqual(test.count, 0)
            XCTAssertTrue(test.isEmpty)
            XCTAssertEqual(test.first, nil)
            XCTAssertEqual(test.last, nil)

        }

        check(make: { TestObservableArray($0) }, convert: { $0 }, apply: { $0.apply($1) })
        check(make: { TestObservableArray($0) }, convert: { $0.observableArray }, apply: { $0.apply($1) })
        check(make: { TestUpdatableArray($0) }, convert: { $0 }, apply: { $0.apply($1) })
        check(make: { TestUpdatableArray($0) }, convert: { $0.observableArray }, apply: { $0.apply($1) })
        check(make: { TestUpdatableArray($0) }, convert: { $0.updatableArray }, apply: { $0.apply($1) })
        check(make: { TestUpdatableArray($0) }, convert: { $0.updatableArray.observableArray }, apply: { $0.apply($1) })
        check(isBuffered: true, make: { ArrayVariable($0) }, convert: { $0 }, apply: { $0.apply($1) })
        check(isBuffered: true, make: { ArrayVariable($0) }, convert: { $0.observableArray }, apply: { $0.apply($1) })
        check(isBuffered: true, make: { ArrayVariable($0) }, convert: { $0.updatableArray }, apply: { $0.apply($1) })
        check(isBuffered: true, make: { ArrayVariable($0) }, convert: { $0.updatableArray.observableArray }, apply: { $0.apply($1) })
    }

    func testConstant() {
        let test = ObservableArray.constant([1, 2, 3])
        XCTAssertTrue(test.isBuffered)
        XCTAssertEqual(test.count, 3)
        XCTAssertEqual(test.value, [1, 2, 3])
        XCTAssertEqual(test[0], 1)
        XCTAssertEqual(test[1], 2)
        XCTAssertEqual(test[2], 3)
        XCTAssertEqual(test[0 ..< 2], [1, 2])

        let mock = MockArrayObserver(test)
        mock.expectingNoChange {
            // Whatevs
        }

        XCTAssertEqual(test.observableCount.value, 3)
        XCTAssertEqual(test.observable.value, [1, 2, 3])
    }

    func testUpdatable() {
        func check<A: UpdatableArrayType>(make: ([Int]) -> A) where A.Element == Int, A.Change == ArrayChange<Int> {
            let test = make([1, 2, 3])

            let mock = MockArrayObserver(test)

            mock.expectingNoChange {
                test.apply(ArrayChange(initialCount: test.count))
            }

            mock.expecting(3, [.remove(1, at: 0), .insert(4, at: 1)]) {
                var change = ArrayChange<Int>(initialCount: 3)
                change.add(.insert(4, at: 2))
                change.add(.remove(1, at: 0))
                test.apply(change)
            }
            XCTAssertEqual(test.value, [2, 4, 3])

            mock.expecting(3, .replaceSlice([2, 4, 3], at: 0, with: [-1, -2, -3])) {
                test.value = [-1, -2, -3]
            }
            XCTAssertEqual(test.value, [-1, -2, -3])

            mock.expecting(3, .replace(-2, at: 1, with: 2)) {
                test[1] = 2
            }
            XCTAssertEqual(test.value, [-1, 2, -3])

            mock.expecting(3, .replaceSlice([-1, 2], at: 0, with: [1, 2])) {
                test[0 ..< 2] = [1, 2]
            }
            XCTAssertEqual(test.value, [1, 2, -3])

            let updatable = test.updatable
            XCTAssertEqual(updatable.value, [1, 2, -3])
            let umock = MockValueObserver(updatable.map { "\($0)" }) // The mapping transforms the array into something equatable
            mock.expecting(3, .replaceSlice([1, 2, -3], at: 0, with: [0, 1, 2, 3])) {
                umock.expecting(.init(from: "[1, 2, -3]", to: "[0, 1, 2, 3]")) {
                    updatable.value = [0, 1, 2, 3]
                }
            }
            XCTAssertEqual(updatable.value, [0, 1, 2, 3])
            XCTAssertEqual(test.value, [0, 1, 2, 3])

            mock.expecting(4, [.insert(10, at: 1), .remove(2, at: 3)]) {
                test.batchUpdate {
                    test.remove(at: 2)
                    test.insert(10, at: 1)
                }
            }
            XCTAssertEqual(test.value, [0, 10, 1, 3])

            mock.expecting(4, [.replaceSlice([1, 3], at: 2, with: [11, 12, 13])]) {
                test.replaceSubrange(2 ..< 4, with: 11 ... 13)
            }
            XCTAssertEqual(test.value, [0, 10, 11, 12, 13])

            mock.expecting(5, [.replaceSlice([0], at: 0, with: [8, 9])]) {
                test.replaceSubrange(0 ..< 1, with: [8, 9])
            }
            XCTAssertEqual(test.value, [8, 9, 10, 11, 12, 13])

            mock.expecting(6, [.insert(14, at: 6)]) {
                test.append(14)
            }
            XCTAssertEqual(test.value, [8, 9, 10, 11, 12, 13, 14])

            mock.expecting(7, [.replaceSlice([], at: 7, with: [15, 16, 17])]) {
                test.append(contentsOf: 15 ... 17)
            }
            XCTAssertEqual(test.value, [8, 9, 10, 11, 12, 13, 14, 15, 16, 17])

            mock.expecting(10, .insert(20, at: 3)) {
                test.insert(20, at: 3)
            }
            XCTAssertEqual(test.value, [8, 9, 10, 20, 11, 12, 13, 14, 15, 16, 17])

            mock.expecting(11, .replaceSlice([], at: 4, with: [21, 22, 23])) {
                test.insert(contentsOf: 21 ... 23, at: 4)
            }
            XCTAssertEqual(test.value, [8, 9, 10, 20, 21, 22, 23, 11, 12, 13, 14, 15, 16, 17])

            mock.expecting(14, .remove(21, at: 4)) {
                XCTAssertEqual(test.remove(at: 4), 21)
            }
            XCTAssertEqual(test.value, [8, 9, 10, 20, 22, 23, 11, 12, 13, 14, 15, 16, 17])

            mock.expecting(13, .replaceSlice([20, 22, 23], at: 3, with: [])) {
                test.removeSubrange(3 ..< 6)
            }
            XCTAssertEqual(test.value, [8, 9, 10, 11, 12, 13, 14, 15, 16, 17])

            mock.expecting(10, .remove(8, at: 0)) {
                XCTAssertEqual(test.removeFirst(), 8)
            }
            XCTAssertEqual(test.value, [9, 10, 11, 12, 13, 14, 15, 16, 17])

            mock.expecting(9, .replaceSlice([9, 10], at: 0, with: [])) {
                test.removeFirst(2)
            }
            XCTAssertEqual(test.value, [11, 12, 13, 14, 15, 16, 17])

            mock.expecting(7, .remove(17, at: 6)) {
                XCTAssertEqual(test.removeLast(), 17)
            }
            XCTAssertEqual(test.value, [11, 12, 13, 14, 15, 16])

            mock.expecting(6, .replaceSlice([14, 15, 16], at: 3, with: [])) {
                test.removeLast(3)
            }
            XCTAssertEqual(test.value, [11, 12, 13])

            mock.expecting(3, .replaceSlice([11, 12, 13], at: 0, with: [])) {
                test.removeAll()
            }
            XCTAssertEqual(test.value, [])
        }

        check { TestUpdatableArray<Int>($0) }
        check { TestUpdatableArray<Int>($0).updatableArray }
        check { TestUpdatableArray<Int>($0).updatableArray.updatableArray }
        check { ArrayVariable<Int>($0) }
        check { ArrayVariable<Int>($0).updatableArray }
    }
}
