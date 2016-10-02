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
        XCTAssertEqual(mod.startIndex, 2)
        XCTAssertEqual(mod.inputRange, 2..<2)
        XCTAssertEqual(mod.outputRange, 2..<3)
        XCTAssertEqual(mod.oldElements, [])
        XCTAssertEqual(mod.newElements, [10])

        a.apply(mod)
        XCTAssertEqual(a, [1, 2, 10, 3])

        XCTAssert(mod.reversed == .remove(10, at: 2))
        XCTAssert(mod.map { "\($0)" } == .insert("10", at: 2))
    }

    func testRemoval() {
        var a = [1, 2, 3]
        let mod = ArrayModification<Int>.remove(2, at: 1)

        XCTAssertEqual(mod.deltaCount, -1)
        XCTAssertEqual(mod.startIndex, 1)
        XCTAssertEqual(mod.inputRange, 1..<2)
        XCTAssertEqual(mod.outputRange, 1..<1)
        XCTAssertEqual(mod.oldElements, [2])
        XCTAssertEqual(mod.newElements, [])

        a.apply(mod)
        XCTAssertEqual(a, [1, 3])

        XCTAssert(mod.reversed == .insert(2, at: 1))
        XCTAssert(mod.map { "\($0)" } == .remove("2", at: 1))
    }

    func testReplacement() {
        var a = [1, 2, 3]
        let mod = ArrayModification.replace(2, at: 1, with: 10)

        XCTAssertEqual(mod.deltaCount, 0)
        XCTAssertEqual(mod.startIndex, 1)
        XCTAssertEqual(mod.inputRange, 1..<2)
        XCTAssertEqual(mod.outputRange, 1..<2)
        XCTAssertEqual(mod.oldElements, [2])
        XCTAssertEqual(mod.newElements, [10])

        a.apply(mod)
        XCTAssertEqual(a, [1, 10, 3])

        XCTAssert(mod.reversed == .replace(10, at: 1, with: 2))
        XCTAssert(mod.map { "\($0)" } == .replace("2", at: 1, with: "10"))
    }

    func testRangeReplacement() {
        var a = [1, 2, 3]
        let mod = ArrayModification.replaceSlice([2], at: 1, with: [10, 20])

        XCTAssertEqual(mod.deltaCount, 1)
        XCTAssertEqual(mod.startIndex, 1)
        XCTAssertEqual(mod.inputRange, 1..<2)
        XCTAssertEqual(mod.outputRange, 1..<3)
        XCTAssertEqual(mod.oldElements, [2])
        XCTAssertEqual(mod.newElements, [10, 20])

        a.apply(mod)
        XCTAssertEqual(a, [1, 10, 20, 3])

        XCTAssert(mod.reversed == .replaceSlice([10, 20], at: 1, with: [2]))
        XCTAssert(mod.map { "\($0)" } == ArrayModification.replaceSlice(["2"], at: 1, with: ["10", "20"]))
    }

    func testMergeIntoEmpty() {
        let first = ArrayModification.replaceSlice([], at: 10, with: ["a", "b", "c"])

        let m1 = ArrayModification<String>.replaceSlice(["a", "b", "c"], at: 10, with: [])
        XCTAssert(first.merged(with: m1) == .collapsedToNoChange)
    }

    func testMergeIntoNonEmpty() {
        func x(_ n: Int) -> [String] { return Array(repeating: "x", count: n) }

        let first = ArrayModification(replacing: x(10), at: 10, with: ["a", "b", "c"])!
        // final range of first: 10..<13

        let m1 = ArrayModification(replacing: ["x", "x", "x", "x", "x"], at: 1, with: ["1", "2"])
        XCTAssert(first.merged(with: m1!) == .disjunctOrderedBefore)

        let m2 = ArrayModification(replacing: ["x", "x", "x", "x", "x"], at: 5, with: ["1", "2"])
        XCTAssert(first.merged(with: m2!) == .collapsedTo(.replaceSlice(x(15), at: 5, with: ["1", "2", "a", "b", "c"])))

        let m3 = ArrayModification(replacing: ["x", "x", "x", "x", "x", "a"], at: 5, with: ["1", "2"])
        XCTAssert(first.merged(with: m3!) == .collapsedTo(.replaceSlice(x(15), at: 5, with: ["1", "2", "b", "c"])))

        let m4 = ArrayModification(replacing: ["x", "a", "b", "c", "x", "x"], at: 9, with: ["1", "2"])
        XCTAssert(first.merged(with: m4!) == .collapsedTo(.replaceSlice(x(13), at: 9, with: ["1", "2"])))

        let m5 = ArrayModification(replacing: [], at: 10, with: ["1", "2"])
        XCTAssert(first.merged(with: m5!) == .collapsedTo(.replaceSlice(x(10), at: 10, with: ["1", "2", "a", "b", "c"])))

        let m6 = ArrayModification(replacing: ["a"], at: 10, with: ["1", "2"])
        XCTAssert(first.merged(with: m6!) == .collapsedTo(.replaceSlice(x(10), at: 10, with: ["1", "2", "b", "c"])))

        let m7 = ArrayModification(replacing: ["a", "b", "c"], at: 10, with: ["1", "2"])
        XCTAssert(first.merged(with: m7!) == .collapsedTo(.replaceSlice(x(10), at: 10, with: ["1", "2"])))

        let m8 = ArrayModification(replacing: ["a", "b", "c", "x"], at: 10, with: ["1", "2"])
        XCTAssert(first.merged(with: m8!) == .collapsedTo(.replaceSlice(x(11), at: 10, with: ["1", "2"])))

        let m9 = ArrayModification(replacing: ["b"], at: 11, with: ["1", "2"])
        XCTAssert(first.merged(with: m9!) == .collapsedTo(.replaceSlice(x(10), at: 10, with: ["a", "1", "2", "c"])))

        let m10 = ArrayModification(replacing: ["b", "c", "x", "x"], at: 11, with: ["1", "2"])
        XCTAssert(first.merged(with: m10!) == .collapsedTo(.replaceSlice(x(12), at: 10, with: ["a", "1", "2"])))

        let m11 = ArrayModification(replacing: ["b", "c", "x", "x", "x", "x", "x", "x", "x"], at: 11, with: ["1", "2"])
        XCTAssert(first.merged(with: m11!) == .collapsedTo(.replaceSlice(x(17), at: 10, with: ["a", "1", "2"])))

        let m12 = ArrayModification(replacing: [], at: 13, with: ["1", "2"])
        XCTAssert(first.merged(with: m12!) == .collapsedTo(.replaceSlice(x(10), at: 10, with: ["a", "b", "c", "1", "2"])))

        let m13 = ArrayModification(replacing: ["x"], at: 13, with: ["1", "2"])
        XCTAssert(first.merged(with: m13!) == .collapsedTo(.replaceSlice(x(11), at: 10, with: ["a", "b", "c", "1", "2"])))

        let m14 = ArrayModification(replacing: [], at: 14, with: ["1", "2"])
        XCTAssert(first.merged(with: m14!) == .disjunctOrderedAfter)

        let m15 = ArrayModification(replacing: x(6), at: 25, with: ["1", "2"])
        XCTAssert(first.merged(with: m15!) == .disjunctOrderedAfter)
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
                print("    Replace \(t.oldElements) at \(t.startIndex) with \(t.newElements)")
            }
            print("Was collapsed to:")
            for m in change.modifications {
                print("    Replace \(m.oldElements) at \(m.startIndex) with \(m.newElements)")
            }
            print("Which resulted in:")
            print("     \(applied)")
            print("Instead of:")
            print("     \(output)")
        }

        func recurse(_ level: Int, input: [Int], change: ArrayChange<Int>, output: [Int], trace: [ArrayModification<Int>]) {
            var applied = input
            XCTAssertEqual(applied.count, change.initialCount)
            for m in change.modifications {
                if applied.count < m.inputRange.upperBound {
                    printTrace(input, change: change, output: output, trace: trace, applied: applied)
                    print()
                }
                if Array(applied[m.inputRange]) != m.oldElements {
                    printTrace(input, change: change, output: output, trace: trace, applied: applied)
                    XCTAssertEqual(Array(applied[m.inputRange]), m.oldElements)
                }
                applied.apply(m)
            }
            XCTAssertEqual(applied.count, change.finalCount)
            if applied != output {
                XCTAssertEqual(applied, output)
                printTrace(input, change: change, output: output, trace: trace, applied: applied)
                return
            }

            if level < maxLevels {
                for startIndex in output.startIndex...output.endIndex {
                    for endIndex in startIndex...output.endIndex {
                        for insertion in insertionsAtLevel(level) {
                            if insertion.count == 0 && endIndex == startIndex {
                                // Skip replacing empty with empty
                                continue
                            }
                            var nextOutput = output
                            nextOutput.replaceSubrange(startIndex..<endIndex, with: insertion)
                            let mod = ArrayModification.replaceSlice(Array(output[startIndex ..< endIndex]), at: startIndex, with: insertion)
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
            .merged(with: ArrayChange<Int>(initialCount: 11, modification: .replace(11, at: 1, with: 2)))
            .merged(with: ArrayChange<Int>(initialCount: 11, modification: .remove(13, at: 4)))
            .merged(with: ArrayChange<Int>(initialCount: 10, modification: .replaceSlice([18, 19], at: 8, with: [5, 6])))

        let c2 = ArrayChange<String>(initialCount: 10, modification: .insert("1", at: 3))
            .merged(with: ArrayChange<String>(initialCount: 11, modification: .replace("11", at: 1, with: "2")))
            .merged(with: ArrayChange<String>(initialCount: 11, modification: .remove("13", at: 4)))
            .merged(with: ArrayChange<String>(initialCount: 10, modification: .replaceSlice(["18", "19"], at: 8, with: ["5", "6"])))

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
        XCTAssert([1, 2, 3, 4].elementsEqual(a1.value, by: ==))

        let a2 = ArrayVariable(elements: 1, 2, 3, 4)
        XCTAssert([1, 2, 3, 4].elementsEqual(a2.value, by: ==))

        let a3: ArrayVariable<Int> = [1, 2, 3, 4] // From array literal
        XCTAssert([1, 2, 3, 4].elementsEqual(a3.value, by: ==))
    }

    func testEquality() {
        // Equality tests between two ArrayVariables
        XCTAssertTrue(ArrayVariable([1, 2, 3]).value == ArrayVariable([1, 2, 3]).value)
        XCTAssertFalse(ArrayVariable([1, 2, 3]).value == ArrayVariable([1, 2]).value)

        // Equality tests between ArrayVariable and an array literal
        XCTAssertTrue(ArrayVariable([1, 2, 3]).value == [1, 2, 3])
        XCTAssertFalse(ArrayVariable([1, 2, 3]).value == [1, 2])

        // Equality tests between two different ObservableArrayTypes
        XCTAssertTrue(ArrayVariable([1, 2, 3]).value == ObservableArray(ArrayVariable([1, 2, 3])).value)
        XCTAssertFalse(ArrayVariable([1, 2, 3]).value == ObservableArray(ArrayVariable([1, 2])).value)

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

            let c1 = array.changes.connect { changes.append($0) }
            defer { c1.disconnect() }

            let c2 = array.observable.futureValues.connect { values.append($0) }
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

