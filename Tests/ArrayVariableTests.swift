//
//  ArrayVariableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-09.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import GlueKit

private func ==<T: Equatable>(a: ArrayModificationMergeResult<T>, b: ArrayModificationMergeResult<T>) -> Bool {
    switch a {
    case .disjunctOrderedAfter:
        if case .disjunctOrderedAfter = b {
            return true
        }
        return false
    case .disjunctOrderedBefore:
        if case .disjunctOrderedBefore = b {
            return true
        }
        return false
    case .collapsedToNoChange:
        if case .collapsedToNoChange = b {
            return true
        }
        return false
    case .collapsedTo(let ae):
        if case .collapsedTo(let be) = b {
            return ae == be
        }
        return false
    }
}

class ArrayModificationTests: XCTestCase {

    func testInsertion() {
        var a = [1, 2, 3]
        let mod = ArrayModification.insert(10, at: 2)

        XCTAssertEqual(mod.deltaCount, 1)
        XCTAssertEqual(mod.range, 2..<2)
        XCTAssertEqual(mod.elements, [10])

        XCTAssert(mod.map { "\($0)" } == ArrayModification.insert("10", at: 2))

        a.apply(mod)

        XCTAssertEqual(a, [1, 2, 10, 3])
    }

    func testRemoval() {
        var a = [1, 2, 3]
        let mod = ArrayModification<Int>.removeAt(1)

        XCTAssertEqual(mod.deltaCount, -1)
        XCTAssertEqual(mod.range, 1..<2)
        XCTAssertEqual(mod.elements, [])

        a.apply(mod)

        XCTAssert(mod.map { "\($0)" } == ArrayModification<String>.removeAt(1))

        XCTAssertEqual(a, [1, 3])
    }

    func testReplacement() {
        var a = [1, 2, 3]
        let mod = ArrayModification.replaceAt(1, with: 10)

        XCTAssertEqual(mod.deltaCount, 0)
        XCTAssertEqual(mod.range, 1..<2)
        XCTAssertEqual(mod.elements, [10])

        a.apply(mod)

        XCTAssert(mod.map { "\($0)" } == ArrayModification.replaceAt(1, with: "10"))

        XCTAssertEqual(a, [1, 10, 3])
    }

    func testRangeReplacement() {
        var a = [1, 2, 3]
        let mod = ArrayModification.replaceRange(1..<2, with: [10, 20])

        XCTAssertEqual(mod.deltaCount, 1)
        XCTAssertEqual(mod.range, 1..<2)
        XCTAssertEqual(mod.elements, [10, 20])

        a.apply(mod)

        XCTAssert(mod.map { "\($0)" } == ArrayModification.replaceRange(1..<2, with: ["10", "20"]))

        XCTAssertEqual(a, [1, 10, 20, 3])
    }

    func testMergeIntoEmpty() {
        let first = ArrayModification.replaceRange(10..<10, with: ["a", "b", "c"])

        let m1 = ArrayModification<String>.replaceRange(10..<13, with: [])
        XCTAssert(first.merged(with: m1) == ArrayModificationMergeResult.collapsedToNoChange)
    }

    func testMergeIntoNonEmpty() {
        let first = ArrayModification.replaceRange(10..<20, with: ["a", "b", "c"])
        // final range of first: 10..<13

        let m1 = ArrayModification.replaceRange(1..<5, with: ["1", "2"])
        XCTAssert(first.merged(with: m1) == ArrayModificationMergeResult.disjunctOrderedBefore)

        let m2 = ArrayModification.replaceRange(5..<10, with: ["1", "2"])
        XCTAssert(first.merged(with: m2) == ArrayModificationMergeResult.collapsedTo(.replaceRange(5..<20, with: ["1", "2", "a", "b", "c"])))

        let m3 = ArrayModification.replaceRange(5..<11, with: ["1", "2"])
        XCTAssert(first.merged(with: m3) == ArrayModificationMergeResult.collapsedTo(.replaceRange(5..<20, with: ["1", "2", "b", "c"])))

        let m4 = ArrayModification.replaceRange(9..<15, with: ["1", "2"])
        XCTAssert(first.merged(with: m4) == ArrayModificationMergeResult.collapsedTo(.replaceRange(9..<22, with: ["1", "2"])))

        let m5 = ArrayModification.replaceRange(10..<10, with: ["1", "2"])
        XCTAssert(first.merged(with: m5) == ArrayModificationMergeResult.collapsedTo(.replaceRange(10..<20, with: ["1", "2", "a", "b", "c"])))

        let m6 = ArrayModification.replaceRange(10..<11, with: ["1", "2"])
        XCTAssert(first.merged(with: m6) == ArrayModificationMergeResult.collapsedTo(.replaceRange(10..<20, with: ["1", "2", "b", "c"])))

        let m7 = ArrayModification.replaceRange(10..<13, with: ["1", "2"])
        XCTAssert(first.merged(with: m7) == ArrayModificationMergeResult.collapsedTo(.replaceRange(10..<20, with: ["1", "2"])))

        let m8 = ArrayModification.replaceRange(10..<14, with: ["1", "2"])
        XCTAssert(first.merged(with: m8) == ArrayModificationMergeResult.collapsedTo(.replaceRange(10..<21, with: ["1", "2"])))

        let m9 = ArrayModification.replaceRange(11..<12, with: ["1", "2"])
        XCTAssert(first.merged(with: m9) == ArrayModificationMergeResult.collapsedTo(.replaceRange(10..<20, with: ["a", "1", "2", "c"])))

        let m10 = ArrayModification.replaceRange(11..<15, with: ["1", "2"])
        XCTAssert(first.merged(with: m10) == ArrayModificationMergeResult.collapsedTo(.replaceRange(10..<22, with: ["a", "1", "2"])))

        let m11 = ArrayModification.replaceRange(11..<20, with: ["1", "2"])
        XCTAssert(first.merged(with: m11) == ArrayModificationMergeResult.collapsedTo(.replaceRange(10..<27, with: ["a", "1", "2"])))

        let m12 = ArrayModification.replaceRange(13..<13, with: ["1", "2"])
        XCTAssert(first.merged(with: m12) == ArrayModificationMergeResult.collapsedTo(.replaceRange(10..<20, with: ["a", "b", "c", "1", "2"])))

        let m13 = ArrayModification.replaceRange(13..<14, with: ["1", "2"])
        XCTAssert(first.merged(with: m13) == ArrayModificationMergeResult.collapsedTo(.replaceRange(10..<21, with: ["a", "b", "c", "1", "2"])))

        let m14 = ArrayModification.replaceRange(14..<14, with: ["1", "2"])
        XCTAssert(first.merged(with: m14) == ArrayModificationMergeResult.disjunctOrderedAfter)

        let m15 = ArrayModification.replaceRange(25..<31, with: ["1", "2"])
        XCTAssert(first.merged(with: m15) == ArrayModificationMergeResult.disjunctOrderedAfter)
    }
}

class ArrayChangeTests: XCTestCase {

    func testExerciseMerging() {
        // Exhaustively test the merging of all variations of modification sequences.
        let startSequence = [0, 1]
        let maxLevels = 4
        let maxInsertionLength = 2

        func insertionsAtLevel(_ level: Int) -> [[Int]] {
            // Returns an array of [], [31], [31, 32], ..., up to maxInsertionLength
            let s = 10 * level
            return (1...maxInsertionLength).map { (1...$0).map { s + $0 } }
        }

        func printTrace(_ input: [Int], change: ArrayChange<Int>, output: [Int], trace: [ArrayModification<Int>], applied: [Int]) {
            print("Given this input:")
            print("    \(input)")
            print("This sequence of changes:")
            for t in trace {
                print("    Replace \(t.range) with \(t.elements)")
            }
            print("Was collapsed to:")
            for m in change.modifications {
                print("    Replace \(m.range) with \(m.elements)")
            }
            print("Which resulted in:")
            print("     \(applied)")
            print("Instead of:")
            print("     \(output)")
        }

        func recurse(_ level: Int, input: [Int], change: ArrayChange<Int>, output: [Int], trace: [ArrayModification<Int>]) {
            let applied = change.apply(on: input)
            if applied != output {
                XCTAssertEqual(applied, output)
                printTrace(input, change: change, output: output, trace: trace, applied: applied)
                return
            }

            if level < maxLevels {
                for startIndex in output.startIndex...output.endIndex {
                    for endIndex in startIndex...output.endIndex {
                        for insertion in insertionsAtLevel(level) {
                            if insertion.count == 0 && endIndex - startIndex == 0 {
                                // Skip replacing empty range to empty array
                                continue
                            }
                            var nextOutput = output
                            nextOutput.replaceSubrange(startIndex..<endIndex, with: insertion)
                            let mod = ArrayModification.replaceRange(startIndex..<endIndex, with: insertion)
                            let nextChange = change.merged(with: ArrayChange(initialCount: output.count, modification: mod))
                            recurse(level + 1, input: input, change: nextChange, output: nextOutput, trace: trace + [mod])
                        }
                    }
                }
            }
        }

        let startChange = ArrayChange<Int>(initialCount: startSequence.count, modifications: [])
        recurse(1, input: startSequence, change: startChange, output: startSequence, trace: [])
    }

    func testMap() {
        let c1 = ArrayChange<Int>(initialCount: 10, modification: .insert(1, at: 3))
            .merged(with: ArrayChange<Int>(initialCount: 11, modification: .replaceAt(1, with: 2)))
            .merged(with: ArrayChange<Int>(initialCount: 11, modification: .removeAt(4)))
            .merged(with: ArrayChange<Int>(initialCount: 10, modification: .replaceRange(8..<10, with: [5, 6])))

        let c2 = ArrayChange<String>(initialCount: 10, modification: .insert("1", at: 3))
            .merged(with: ArrayChange<String>(initialCount: 11, modification: .replaceAt(1, with: "2")))
            .merged(with: ArrayChange<String>(initialCount: 11, modification: .removeAt(4)))
            .merged(with: ArrayChange<String>(initialCount: 10, modification: .replaceRange(8..<10, with: ["5", "6"])))

        let m = c1.map { "\($0)" }
        XCTAssertEqual(m.initialCount, c2.initialCount)
        XCTAssertEqual(m.deltaCount, c2.deltaCount)
        XCTAssert(m.modifications.elementsEqual(c2.modifications, by: ==))
    }
}


class ArrayVariableTests: XCTestCase {
    func testArrayInitialization() {
        let a0 = ArrayVariable<Int>() // Empty
        XCTAssertEqual(a0.count, 0)

        let a1 = ArrayVariable([1, 2, 3, 4])
        XCTAssert([1, 2, 3, 4].elementsEqual(a1, by: ==))

        let a2 = ArrayVariable(elements: 1, 2, 3, 4)
        XCTAssert([1, 2, 3, 4].elementsEqual(a2, by: ==))

        let a3: ArrayVariable<Int> = [1, 2, 3, 4] // From array literal
        XCTAssert([1, 2, 3, 4].elementsEqual(a3, by: ==))
    }

    func testEquality() {
        // Equality tests between two ArrayVariables
        XCTAssertTrue(ArrayVariable([1, 2, 3]) == ArrayVariable([1, 2, 3]))
        XCTAssertFalse(ArrayVariable([1, 2, 3]) == ArrayVariable([1, 2]))

        // Equality tests between ArrayVariable and an array literal
        XCTAssertTrue(ArrayVariable([1, 2, 3]) == [1, 2, 3])
        XCTAssertFalse(ArrayVariable([1, 2, 3]) == [1, 2])

        // Equality tests between two different ObservableArrayTypes
        XCTAssertTrue(ArrayVariable([1, 2, 3]) == ObservableArray(ArrayVariable([1, 2, 3])))
        XCTAssertFalse(ArrayVariable([1, 2, 3]) == ObservableArray(ArrayVariable([1, 2])))

        // Equality tests between an ArrayVariable and an Array
        XCTAssertTrue(ArrayVariable([1, 2, 3]) == Array([1, 2, 3]))
        XCTAssertFalse(ArrayVariable([1, 2, 3]) == Array([1, 2]))
        XCTAssertTrue(Array([1, 2, 3]) == ArrayVariable([1, 2, 3]))
        XCTAssertFalse(Array([1, 2]) == ArrayVariable([1, 2, 3]))
    }

    func testValueAndCount() {
        let array: ArrayVariable<Int> = [1, 2, 3]

        XCTAssertEqual(array.value, [1, 2, 3])
        XCTAssertEqual(array.count, 3)

        array.value = [4, 5]

        XCTAssertEqual(array.value, [4, 5])
        XCTAssertEqual(array.count, 2)

        array.setValue([6])

        XCTAssertEqual(array.value, [6])
        XCTAssertEqual(array.count, 1)
    }

    func testGenerate() {
        let array: ArrayVariable<Int> = [1, 2, 3, 4]
        var g = array.makeIterator()
        XCTAssertEqual(g.next(), 1)
        XCTAssertEqual(g.next(), 2)
        XCTAssertEqual(g.next(), 3)
        XCTAssertEqual(g.next(), 4)
        XCTAssertEqual(g.next(), nil)
    }

    func testIndexing() {
        let array: ArrayVariable<Int> = [1, 2, 3]

        XCTAssertEqual(array[1], 2)

        array[2] = 10

        XCTAssertEqual(array[2], 10)

        XCTAssert([1, 2, 10].elementsEqual(array, by: ==))
    }

    func testIndexingWithRanges() {
        let array: ArrayVariable<Int> = [1, 2, 3, 4]

        XCTAssertEqual(array[1...2], [2, 3])

        array[1..<3] = [20, 30, 40]

        XCTAssertEqual(array.value, [1, 20, 30, 40, 4])
    }

    func testChangeNotifications() {
        func tryCase(_ input: [Int], op: (ArrayVariable<Int>) -> (), expectedOutput: [Int], expectedChange: ArrayChange<Int>) {
            let array = ArrayVariable<Int>(input)

            var changes = [ArrayChange<Int>]()
            var values = [[Int]]()

            let c1 = array.futureChanges.connect { changes.append($0) }
            defer { c1.disconnect() }

            let c2 = array.observable.futureValues.connect { values.append($0) }
            defer { c2.disconnect() }

            op(array)

            XCTAssertEqual(array.value, expectedOutput)
            XCTAssertEqual(values, [expectedOutput])
            XCTAssertTrue(changes.count == 1 && changes[0] == expectedChange)
        }

        tryCase([1, 2, 3], op: { $0[1] = 20 },
            expectedOutput: [1, 20, 3], expectedChange: ArrayChange(initialCount: 3, modification: .replaceAt(1, with: 20)))

        tryCase([1, 2, 3], op: { $0[1..<2] = [20, 30] },
            expectedOutput: [1, 20, 30, 3], expectedChange: ArrayChange(initialCount: 3, modification: .replaceRange(1..<2, with: [20, 30])))

        tryCase([1, 2, 3], op: { $0.setValue([4, 5]) },
            expectedOutput: [4, 5], expectedChange: ArrayChange(initialCount: 3, modification: .replaceRange(0..<3, with: [4, 5])))

        tryCase([1, 2, 3], op: { $0.value = [4, 5] },
            expectedOutput: [4, 5], expectedChange: ArrayChange(initialCount: 3, modification: .replaceRange(0..<3, with: [4, 5])))

        tryCase([1, 2, 3], op: { $0.replaceSubrange(0..<2, with: [5, 6, 7]) },
            expectedOutput: [5, 6, 7, 3], expectedChange: ArrayChange(initialCount: 3, modification: .replaceRange(0..<2, with: [5, 6, 7])))

        tryCase([1, 2, 3], op: { $0.append(10) },
            expectedOutput: [1, 2, 3, 10], expectedChange: ArrayChange(initialCount: 3, modification: .insert(10, at: 3)))

        tryCase([1, 2, 3], op: { $0.insert(10, at: 2) },
            expectedOutput: [1, 2, 10, 3], expectedChange: ArrayChange(initialCount: 3, modification: .insert(10, at: 2)))

        tryCase([1, 2, 3], op: { $0.remove(at: 1) },
            expectedOutput: [1, 3], expectedChange: ArrayChange(initialCount: 3, modification: .removeAt(1)))

        tryCase([1, 2, 3], op: { $0.removeFirst() },
            expectedOutput: [2, 3], expectedChange: ArrayChange(initialCount: 3, modification: .removeAt(0)))

        tryCase([1, 2, 3], op: { $0.removeLast() },
            expectedOutput: [1, 2], expectedChange: ArrayChange(initialCount: 3, modification: .removeAt(2)))

        tryCase([1, 2, 3], op: { $0.removeAll() },
            expectedOutput: [], expectedChange: ArrayChange(initialCount: 3, modification: .replaceRange(0..<3, with: [])))

    }

}

