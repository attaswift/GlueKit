//
//  ObservableArrayTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-10.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

class TestObservableArray<Element>: ObservableArrayType, TransactionalThing {
    typealias Change = ArrayChange<Element>

    var _signal: TransactionalSignal<ArrayChange<Element>>? = nil
    var _transactionCount: Int = 0
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

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<ArrayChange<Element>> {
        signal.add(sink)
    }

    @discardableResult
    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<ArrayChange<Element>> {
        return signal.remove(sink)
    }

    func apply(_ change: ArrayChange<Element>) {
        if change.isEmpty { return }
        beginTransaction()
        _value.apply(change)
        sendChange(change)
        endTransaction()
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

    func withTransaction<Result>(_ body: () -> Result) -> Result {
        beginTransaction()
        defer { endTransaction() }
        return body()
    }

    func apply(_ update: Update<ArrayChange<Element>>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            _value.apply(change)
            sendChange(change)
        case .endTransaction:
            endTransaction()
        }
    }
}

class ObservableArrayTests: XCTestCase {
    func testDefaultImplementations() {
        func check<T, A: ObservableArrayType>(isBuffered: Bool = false, make: ([Int]) -> T, convert: (T) -> A, apply: @escaping (T, ArrayChange<Int>) -> Void) where A.Element == Int {
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

            let observable = test.anyObservableValue
            let observableCount = test.observableCount

            XCTAssertEqual(observable.value, [1, 2, 3])
            XCTAssertEqual(observableCount.value, 3)

            let mock = MockArrayObserver(test)
            let valueMock = MockValueUpdateSink(observable.map { "\($0)" }) // map is to convert array into something equatable
            let countMock = MockValueUpdateSink(observableCount)

            mock.expecting(["begin", "3.insert(4, at: 2)", "end"]) {
                valueMock.expecting(["begin", "[1, 2, 3] -> [1, 2, 4, 3]", "end"]) {
                    countMock.expecting(["begin", "3 -> 4", "end"]) {
                        apply(t, ArrayChange<Int>(initialCount: 3, modification: .insert(4, at: 2)))
                    }
                }
            }
            XCTAssertEqual(test.value, [1, 2, 4, 3])
            XCTAssertEqual(observable.value, [1, 2, 4, 3])
            XCTAssertEqual(observableCount.value, 4)

            mock.expecting(["begin", "4.replaceSlice([1, 2, 4, 4], at: 0, with: [])", "end"]) {
                valueMock.expecting(["begin", "[1, 2, 4, 3] -> []", "end"]) {
                    countMock.expecting(["begin", "4 -> 0", "end"]) {
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
        check(make: { TestObservableArray($0) }, convert: { $0.anyObservableArray }, apply: { $0.apply($1) })
        check(make: { TestUpdatableArray($0) }, convert: { $0 }, apply: { $0.apply($1) })
        check(make: { TestUpdatableArray($0) }, convert: { $0.anyObservableArray }, apply: { $0.apply($1) })
        check(make: { TestUpdatableArray($0) }, convert: { $0.anyUpdatableArray }, apply: { $0.apply($1) })
        check(make: { TestUpdatableArray($0) }, convert: { $0.anyUpdatableArray.anyObservableArray }, apply: { $0.apply($1) })
        check(isBuffered: true, make: { ArrayVariable($0) }, convert: { $0 }, apply: { $0.apply($1) })
        check(isBuffered: true, make: { ArrayVariable($0) }, convert: { $0.anyObservableArray }, apply: { $0.apply($1) })
        check(isBuffered: true, make: { ArrayVariable($0) }, convert: { $0.anyUpdatableArray }, apply: { $0.apply($1) })
        check(isBuffered: true, make: { ArrayVariable($0) }, convert: { $0.anyUpdatableArray.anyObservableArray }, apply: { $0.apply($1) })

        check(isBuffered: true, make: { TestObservableArray($0) }, convert: { $0.buffered() }, apply: { $0.apply($1) })
        check(isBuffered: true, make: { ArrayVariable($0) }, convert: { $0.buffered() }, apply: { $0.apply($1) })
    }

    func testConstant() {
        let test = AnyObservableArray.constant([1, 2, 3])
        XCTAssertTrue(test.isBuffered)
        XCTAssertEqual(test.count, 3)
        XCTAssertEqual(test.value, [1, 2, 3])
        XCTAssertEqual(test[0], 1)
        XCTAssertEqual(test[1], 2)
        XCTAssertEqual(test[2], 3)
        XCTAssertEqual(test[0 ..< 2], [1, 2])

        let mock = MockArrayObserver(test)
        mock.expectingNothing {
            // Whatevs
        }

        XCTAssertEqual(test.observableCount.value, 3)
        XCTAssertEqual(test.anyObservableValue.value, [1, 2, 3])
    }

    func testUpdatable() {
        func check<A: UpdatableArrayType>(make: ([Int]) -> A) where A.Element == Int {
            let test = make([1, 2, 3])

            let mock = MockArrayObserver(test)

            mock.expectingNothing {
                test.apply(ArrayChange(initialCount: test.count))
            }

            mock.expecting(["begin", "3.remove(1, at: 0).insert(4, at: 1)", "end"]) {
                var change = ArrayChange<Int>(initialCount: 3)
                change.add(.insert(4, at: 2))
                change.add(.remove(1, at: 0))
                test.apply(change)
            }
            XCTAssertEqual(test.value, [2, 4, 3])

            mock.expecting(["begin", "3.replaceSlice([2, 4, 3], at: 0, with: [-1, -2, -3])", "end"]) {
                test.value = [-1, -2, -3]
            }
            XCTAssertEqual(test.value, [-1, -2, -3])

            mock.expecting(["begin", "3.replace(-2, at: 1, with: 2)", "end"]) {
                test[1] = 2
            }
            XCTAssertEqual(test.value, [-1, 2, -3])

            mock.expecting(["begin", "3.replaceSlice([-1, 2], at: 0, with: [1, 2])", "end"]) {
                test[0 ..< 2] = [1, 2]
            }
            XCTAssertEqual(test.value, [1, 2, -3])

            let updatable = test.anyUpdatableValue
            XCTAssertEqual(updatable.value, [1, 2, -3])
            let umock = MockValueUpdateSink(updatable.map { "\($0)" }) // The mapping transforms the array into something equatable
            mock.expecting(["begin", "3.replaceSlice([1, 2, -3], at: 0, with: [0, 1, 2, 3])", "end"]) {
                umock.expecting(["begin", "[1, 2, -3] -> [0, 1, 2, 3]", "end"]) {
                    updatable.value = [0, 1, 2, 3]
                }
            }
            XCTAssertEqual(updatable.value, [0, 1, 2, 3])
            XCTAssertEqual(test.value, [0, 1, 2, 3])

            umock.disconnect()

            mock.expecting(["begin", "4.remove(2, at: 2)", "3.insert(10, at: 1)", "end"]) {
                test.withTransaction {
                    test.remove(at: 2)
                    test.insert(10, at: 1)
                }
            }
            XCTAssertEqual(test.value, [0, 10, 1, 3])

            mock.expecting(["begin", "4.replaceSlice([1, 3], at: 2, with: [11, 12, 13])", "end"]) {
                test.replaceSubrange(2 ..< 4, with: 11 ... 13)
            }
            XCTAssertEqual(test.value, [0, 10, 11, 12, 13])

            mock.expecting(["begin", "5.replaceSlice([0], at: 0, with: [8, 9])", "end"]) {
                test.replaceSubrange(0 ..< 1, with: [8, 9])
            }
            XCTAssertEqual(test.value, [8, 9, 10, 11, 12, 13])

            mock.expecting(["begin", "6.insert(14, at: 6)", "end"]) {
                test.append(14)
            }
            XCTAssertEqual(test.value, [8, 9, 10, 11, 12, 13, 14])

            mock.expecting(["begin", "7.replaceSlice([], at: 7, with: [15, 16, 17])", "end"]) {
                test.append(contentsOf: 15 ... 17)
            }
            XCTAssertEqual(test.value, [8, 9, 10, 11, 12, 13, 14, 15, 16, 17])

            mock.expecting(["begin", "10.insert(20, at: 3)", "end"]) {
                test.insert(20, at: 3)
            }
            XCTAssertEqual(test.value, [8, 9, 10, 20, 11, 12, 13, 14, 15, 16, 17])

            mock.expecting(["begin", "11.replaceSlice([], at: 4, with: [21, 22, 23])", "end"]) {
                test.insert(contentsOf: 21 ... 23, at: 4)
            }
            XCTAssertEqual(test.value, [8, 9, 10, 20, 21, 22, 23, 11, 12, 13, 14, 15, 16, 17])

            mock.expecting(["begin", "14.remove(21, at: 4)", "end"]) {
                XCTAssertEqual(test.remove(at: 4), 21)
            }
            XCTAssertEqual(test.value, [8, 9, 10, 20, 22, 23, 11, 12, 13, 14, 15, 16, 17])

            mock.expecting(["begin", "13.replaceSlice([20, 22, 23], at: 3, with: [])", "end"]) {
                test.removeSubrange(3 ..< 6)
            }
            XCTAssertEqual(test.value, [8, 9, 10, 11, 12, 13, 14, 15, 16, 17])

            mock.expecting(["begin", "10.remove(8, at: 0)", "end"]) {
                XCTAssertEqual(test.removeFirst(), 8)
            }
            XCTAssertEqual(test.value, [9, 10, 11, 12, 13, 14, 15, 16, 17])

            mock.expecting(["begin", "9.replaceSlice([9, 10], at: 0, with: [])", "end"]) {
                test.removeFirst(2)
            }
            XCTAssertEqual(test.value, [11, 12, 13, 14, 15, 16, 17])

            mock.expecting(["begin", "7.remove(17, at: 6)", "end"]) {
                XCTAssertEqual(test.removeLast(), 17)
            }
            XCTAssertEqual(test.value, [11, 12, 13, 14, 15, 16])

            mock.expecting(["begin", "6.replaceSlice([14, 15, 16], at: 3, with: [])", "end"]) {
                test.removeLast(3)
            }
            XCTAssertEqual(test.value, [11, 12, 13])

            mock.expecting(["begin", "3.remove(13, at: 2)", "2.replace(12, at: 1, with: 20)", "end"]) {
                test.withTransaction {
                    test.remove(at: 2)
                    test[1] = 20
                }
            }

            mock.expecting(["begin", "2.replaceSlice([11, 20], at: 0, with: [])", "end"]) {
                test.removeAll()
            }
            XCTAssertEqual(test.value, [])
        }

        check { TestUpdatableArray<Int>($0) }
        check { TestUpdatableArray<Int>($0).anyUpdatableArray }
        check { TestUpdatableArray<Int>($0).anyUpdatableArray.anyUpdatableArray }
        check { ArrayVariable<Int>($0) }
        check { ArrayVariable<Int>($0).anyUpdatableArray }
    }
}
