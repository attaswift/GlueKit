//
//  ArrayVariableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-09.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import GlueKit

private func ==<T: Equatable>(a: ArrayModification<T>, b: ArrayModification<T>) -> Bool {
    return a.range == b.range && a.elements == b.elements
}

private func ==<T: Equatable>(a: ArrayModificationMergeResult<T>, b: ArrayModificationMergeResult<T>) -> Bool {
    switch a {
    case .DisjunctOrderedAfter:
        if case .DisjunctOrderedAfter = b {
            return true
        }
        return false
    case .DisjunctOrderedBefore:
        if case .DisjunctOrderedBefore = b {
            return true
        }
        return false
    case .CollapsedToNoChange:
        if case .CollapsedToNoChange = b {
            return true
        }
        return false
    case .CollapsedTo(let ae):
        if case .CollapsedTo(let be) = b {
            return ae == be
        }
        return false
    }
}

class ArrayModificationTests: XCTestCase {

    func testInsertion() {
        var a = [1, 2, 3]
        let mod = ArrayModification.Insert(10, at: 2)

        XCTAssertEqual(mod.countDelta, 1)
        XCTAssertEqual(mod.range, 2..<2)
        XCTAssertEqual(mod.elements, [10])

        XCTAssert(mod.map { "\($0)" } == ArrayModification.Insert("10", at: 2))

        a.apply(mod)

        XCTAssertEqual(a, [1, 2, 10, 3])
    }

    func testRemoval() {
        var a = [1, 2, 3]
        let mod = ArrayModification<Int>.RemoveAt(1)

        XCTAssertEqual(mod.countDelta, -1)
        XCTAssertEqual(mod.range, 1..<2)
        XCTAssertEqual(mod.elements, [])

        a.apply(mod)

        XCTAssert(mod.map { "\($0)" } == ArrayModification<String>.RemoveAt(1))

        XCTAssertEqual(a, [1, 3])
    }

    func testReplacement() {
        var a = [1, 2, 3]
        let mod = ArrayModification.ReplaceAt(1, with: 10)

        XCTAssertEqual(mod.countDelta, 0)
        XCTAssertEqual(mod.range, 1..<2)
        XCTAssertEqual(mod.elements, [10])

        a.apply(mod)

        XCTAssert(mod.map { "\($0)" } == ArrayModification.ReplaceAt(1, with: "10"))

        XCTAssertEqual(a, [1, 10, 3])
    }

    func testRangeReplacement() {
        var a = [1, 2, 3]
        let mod = ArrayModification.ReplaceRange(1...1, with: [10, 20])

        XCTAssertEqual(mod.countDelta, 1)
        XCTAssertEqual(mod.range, 1..<2)
        XCTAssertEqual(mod.elements, [10, 20])

        a.apply(mod)

        XCTAssert(mod.map { "\($0)" } == ArrayModification.ReplaceRange(1...1, with: ["10", "20"]))

        XCTAssertEqual(a, [1, 10, 20, 3])
    }

    func testMergeIntoEmpty() {
        let first = ArrayModification.ReplaceRange(10..<10, with: ["a", "b", "c"])

        let m1 = ArrayModification<String>.ReplaceRange(10..<13, with: [])
        XCTAssert(first.merge(m1) == ArrayModificationMergeResult.CollapsedToNoChange)
    }

    func testMergeIntoNonEmpty() {
        let first = ArrayModification.ReplaceRange(10..<20, with: ["a", "b", "c"])
        // final range of first: 10..<13

        let m1 = ArrayModification.ReplaceRange(1..<5, with: ["1", "2"])
        XCTAssert(first.merge(m1) == ArrayModificationMergeResult.DisjunctOrderedBefore)

        let m2 = ArrayModification.ReplaceRange(5..<10, with: ["1", "2"])
        XCTAssert(first.merge(m2) == ArrayModificationMergeResult.CollapsedTo(.ReplaceRange(5..<20, with: ["1", "2", "a", "b", "c"])))

        let m3 = ArrayModification.ReplaceRange(5..<11, with: ["1", "2"])
        XCTAssert(first.merge(m3) == ArrayModificationMergeResult.CollapsedTo(.ReplaceRange(5..<20, with: ["1", "2", "b", "c"])))

        let m4 = ArrayModification.ReplaceRange(9..<15, with: ["1", "2"])
        XCTAssert(first.merge(m4) == ArrayModificationMergeResult.CollapsedTo(.ReplaceRange(9..<22, with: ["1", "2"])))

        let m5 = ArrayModification.ReplaceRange(10..<10, with: ["1", "2"])
        XCTAssert(first.merge(m5) == ArrayModificationMergeResult.CollapsedTo(.ReplaceRange(10..<20, with: ["1", "2", "a", "b", "c"])))

        let m6 = ArrayModification.ReplaceRange(10..<11, with: ["1", "2"])
        XCTAssert(first.merge(m6) == ArrayModificationMergeResult.CollapsedTo(.ReplaceRange(10..<20, with: ["1", "2", "b", "c"])))

        let m7 = ArrayModification.ReplaceRange(10..<13, with: ["1", "2"])
        XCTAssert(first.merge(m7) == ArrayModificationMergeResult.CollapsedTo(.ReplaceRange(10..<20, with: ["1", "2"])))

        let m8 = ArrayModification.ReplaceRange(10..<14, with: ["1", "2"])
        XCTAssert(first.merge(m8) == ArrayModificationMergeResult.CollapsedTo(.ReplaceRange(10..<21, with: ["1", "2"])))

        let m9 = ArrayModification.ReplaceRange(11..<12, with: ["1", "2"])
        XCTAssert(first.merge(m9) == ArrayModificationMergeResult.CollapsedTo(.ReplaceRange(10..<20, with: ["a", "1", "2", "c"])))

        let m10 = ArrayModification.ReplaceRange(11..<15, with: ["1", "2"])
        XCTAssert(first.merge(m10) == ArrayModificationMergeResult.CollapsedTo(.ReplaceRange(10..<22, with: ["a", "1", "2"])))

        let m11 = ArrayModification.ReplaceRange(11..<20, with: ["1", "2"])
        XCTAssert(first.merge(m11) == ArrayModificationMergeResult.CollapsedTo(.ReplaceRange(10..<27, with: ["a", "1", "2"])))

        let m12 = ArrayModification.ReplaceRange(13..<13, with: ["1", "2"])
        XCTAssert(first.merge(m12) == ArrayModificationMergeResult.CollapsedTo(.ReplaceRange(10..<20, with: ["a", "b", "c", "1", "2"])))

        let m13 = ArrayModification.ReplaceRange(13..<14, with: ["1", "2"])
        XCTAssert(first.merge(m13) == ArrayModificationMergeResult.CollapsedTo(.ReplaceRange(10..<21, with: ["a", "b", "c", "1", "2"])))

        let m14 = ArrayModification.ReplaceRange(14..<14, with: ["1", "2"])
        XCTAssert(first.merge(m14) == ArrayModificationMergeResult.DisjunctOrderedAfter)

        let m15 = ArrayModification.ReplaceRange(25...30, with: ["1", "2"])
        XCTAssert(first.merge(m15) == ArrayModificationMergeResult.DisjunctOrderedAfter)
    }
}

class ArrayChangeTests: XCTestCase {

    func testExerciseMerging() {
        // Exhaustively test the merging of all variations of modification sequences.
        let startSequence = [0, 1]
        let maxLevels = 4
        let maxInsertionLength = 2

        func insertionsAtLevel(level: Int) -> [[Int]] {
            // Returns an array of [], [31], [31, 32], ..., up to maxInsertionLength
            let s = 10 * level
            return (1...maxInsertionLength).map { (1...$0).map { s + $0 } }
        }

        func printTrace(input: [Int], change: ArrayChange<Int>, output: [Int], trace: [ArrayModification<Int>], applied: [Int]) {
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

        func recurse(level: Int, input: [Int], change: ArrayChange<Int>, output: [Int], trace: [ArrayModification<Int>]) {
            let applied = change.applyOn(input)
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
                            nextOutput.replaceRange(startIndex..<endIndex, with: insertion)
                            let mod = ArrayModification.ReplaceRange(startIndex..<endIndex, with: insertion)
                            let nextChange = change.merge(ArrayChange(count: output.count, modification: mod))
                            recurse(level + 1, input: input, change: nextChange, output: nextOutput, trace: trace + [mod])
                        }
                    }
                }
            }
        }

        let startChange = ArrayChange<Int>(initialCount: startSequence.count, finalCount: startSequence.count, modifications: [])
        recurse(1, input: startSequence, change: startChange, output: startSequence, trace: [])
    }

    func testMap() {
        let c1 = ArrayChange<Int>(count: 10, modification: .Insert(1, at: 3))
            .merge(ArrayChange<Int>(count: 11, modification: .ReplaceAt(1, with: 2)))
            .merge(ArrayChange<Int>(count: 11, modification: .RemoveAt(4)))
            .merge(ArrayChange<Int>(count: 10, modification: .ReplaceRange(8...9, with: [5, 6])))

        let c2 = ArrayChange<String>(count: 10, modification: .Insert("1", at: 3))
            .merge(ArrayChange<String>(count: 11, modification: .ReplaceAt(1, with: "2")))
            .merge(ArrayChange<String>(count: 11, modification: .RemoveAt(4)))
            .merge(ArrayChange<String>(count: 10, modification: .ReplaceRange(8...9, with: ["5", "6"])))

        let m = c1.map { "\($0)" }
        XCTAssertEqual(m.initialCount, c2.initialCount)
        XCTAssertEqual(m.finalCount, c2.finalCount)
        XCTAssert(m.modifications.elementsEqual(c2.modifications, isEquivalent: ==))
    }
}


class ArrayVariableTests: XCTestCase {
}
