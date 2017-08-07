//
//  ArrayVariableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-09.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class ArrayVariableTests: XCTestCase {
    func testArrayInitialization() {
        let a0 = ArrayVariable<Int>() // Empty
        XCTAssertEqual(a0.count, 0)

        let a1 = ArrayVariable([1, 2, 3, 4])
        XCTAssertEqual(a1.value, [1, 2, 3, 4])

        let a2 = ArrayVariable(1 ... 4)
        XCTAssertEqual(a2.value, [1, 2, 3, 4])

        let a3 = ArrayVariable(elements: 1, 2, 3, 4)
        XCTAssertEqual(a3.value, [1, 2, 3, 4])

        let a4: ArrayVariable<Int> = [1, 2, 3, 4] // From array literal
        XCTAssertEqual(a4.value, [1, 2, 3, 4])
    }

    func testEquality() {
        // Equality tests between two ArrayVariables
        XCTAssertTrue(ArrayVariable([1, 2, 3]).value == ArrayVariable([1, 2, 3]).value)
        XCTAssertFalse(ArrayVariable([1, 2, 3]).value == ArrayVariable([1, 2]).value)

        // Equality tests between ArrayVariable and an array literal
        XCTAssertTrue(ArrayVariable([1, 2, 3]).value == [1, 2, 3])
        XCTAssertFalse(ArrayVariable([1, 2, 3]).value == [1, 2])

        // Equality tests between two different ObservableArrayTypes
        XCTAssertTrue(ArrayVariable([1, 2, 3]).value == AnyObservableArray(ArrayVariable([1, 2, 3])).value)
        XCTAssertFalse(ArrayVariable([1, 2, 3]).value == AnyObservableArray(ArrayVariable([1, 2])).value)

        // Equality tests between an ArrayVariable and an Array
        XCTAssertTrue(ArrayVariable([1, 2, 3]).value == Array([1, 2, 3]))
        XCTAssertFalse(ArrayVariable([1, 2, 3]).value == Array([1, 2]))
        XCTAssertTrue(Array([1, 2, 3]) == ArrayVariable([1, 2, 3]).value)
        XCTAssertFalse(Array([1, 2]) == ArrayVariable([1, 2, 3]).value)
    }

    func testValueAndCount() {
        let array: ArrayVariable<Int> = [1, 2, 3]

        XCTAssertEqual(array.value, [1, 2, 3])
        XCTAssertEqual(array.count, 3)

        array.value = [4, 5]

        XCTAssertEqual(array.value, [4, 5])
        XCTAssertEqual(array.count, 2)

        array.value = [6]

        XCTAssertEqual(array.value, [6])
        XCTAssertEqual(array.count, 1)
    }

    func testIndexing() {
        let array: ArrayVariable<Int> = [1, 2, 3]

        XCTAssertEqual(array[1], 2)

        array[2] = 10

        XCTAssertEqual(array[2], 10)

        XCTAssert([1, 2, 10].elementsEqual(array.value, by: ==))
    }

    func testIndexingWithRanges() {
        let array: ArrayVariable<Int> = [1, 2, 3, 4]

        XCTAssertEqual(array[1..<3], [2, 3])

        array[1..<3] = [20, 30, 40]

        XCTAssertEqual(array.value, [1, 20, 30, 40, 4])
    }

    func testChangeNotifications() {
        func tryCase(_ input: [Int], op: (ArrayVariable<Int>) -> (), expectedOutput: [Int], expectedChange: ArrayChange<Int>) {
            let array = ArrayVariable<Int>(input)

            var changes = [ArrayChange<Int>]()
            var values = [[Int]]()

            let c1 = array.changes.subscribe { changes.append($0) }
            defer { c1.disconnect() }

            let c2 = array.anyObservableValue.futureValues.subscribe { values.append($0) }
            defer { c2.disconnect() }

            op(array)

            XCTAssertEqual(array.value, expectedOutput)
            XCTAssertEqual(values, [expectedOutput])
            XCTAssertTrue(changes.count == 1 && changes[0] == expectedChange)
        }

        tryCase([1, 2, 3], op: { $0[1] = 20 },
            expectedOutput: [1, 20, 3], expectedChange: ArrayChange(initialCount: 3, modification: .replace(2, at: 1, with: 20)))

        tryCase([1, 2, 3], op: { $0[1..<2] = [20, 30] },
                expectedOutput: [1, 20, 30, 3], expectedChange: ArrayChange(initialCount: 3, modification: .replaceSlice([2], at: 1, with: [20, 30])))

        tryCase([1, 2, 3], op: { $0.value = [4, 5] },
                expectedOutput: [4, 5], expectedChange: ArrayChange(initialCount: 3, modification: .replaceSlice([1, 2, 3], at: 0, with: [4, 5])))

        tryCase([1, 2, 3], op: { $0.value = [4, 5] },
                expectedOutput: [4, 5], expectedChange: ArrayChange(initialCount: 3, modification: .replaceSlice([1, 2, 3], at: 0, with: [4, 5])))

        tryCase([1, 2, 3], op: { $0.replaceSubrange(0..<2, with: [5, 6, 7]) },
                expectedOutput: [5, 6, 7, 3], expectedChange: ArrayChange(initialCount: 3, modification: .replaceSlice([1, 2], at: 0, with: [5, 6, 7])))

        tryCase([1, 2, 3], op: { $0.append(10) },
                expectedOutput: [1, 2, 3, 10], expectedChange: ArrayChange(initialCount: 3, modification: .insert(10, at: 3)))

        tryCase([1, 2, 3], op: { $0.insert(10, at: 2) },
                expectedOutput: [1, 2, 10, 3], expectedChange: ArrayChange(initialCount: 3, modification: .insert(10, at: 2)))

        tryCase([1, 2, 3], op: { $0.remove(at: 1) },
                expectedOutput: [1, 3], expectedChange: ArrayChange(initialCount: 3, modification: .remove(2, at: 1)))

        tryCase([1, 2, 3], op: { $0.removeFirst() },
                expectedOutput: [2, 3], expectedChange: ArrayChange(initialCount: 3, modification: .remove(1, at: 0)))

        tryCase([1, 2, 3], op: { $0.removeLast() },
                expectedOutput: [1, 2], expectedChange: ArrayChange(initialCount: 3, modification: .remove(3, at: 2)))

        tryCase([1, 2, 3], op: { $0.removeAll() },
                expectedOutput: [], expectedChange: ArrayChange(initialCount: 3, modification: .replaceSlice([1, 2, 3], at: 0, with: [])))

    }
}

