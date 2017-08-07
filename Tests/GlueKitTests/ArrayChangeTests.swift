//
//  ArrayChangeTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit

class ArrayChangeTests: XCTestCase {

    func testCounts() {
        var change = ArrayChange<String>(initialCount: 10)
        change.add(.insert("foo", at: 2))
        change.add(.replace("foo", at: 4, with: "bar"))
        change.add(.remove("foo", at: 0))
        change.add(.replaceSlice(["foo", "bar"], at: 6, with: ["1", "2", "3"]))

        XCTAssertEqual(change.initialCount, 10)
        XCTAssertEqual(change.finalCount, 11)
        XCTAssertEqual(change.deltaCount, 1)
        XCTAssertTrue(change.countChange == ValueChange<Int>(from: 10, to: 11))
    }

    func testExerciseMerging() {
        // Exhaustively test the merging of all variations of modification sequences.
        let startSequence = [0, 1]
        let maxLevels = 4
        let maxInsertionLength = 2

        func insertionsAtLevel(_ level: Int) -> [[Int]] {
            // Returns an array of [], [30], [30, 31], ..., up to maxInsertionLength
            let s = 10 * level
            return (0...maxInsertionLength).map { (0..<$0).map { s + $0 } }
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

            // Also do a quick test for reversing the change.
            var undo = applied
            undo.apply(change.reversed())
            XCTAssertEqual(undo, input)

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

        let startChange = ArrayChange<Int>(initialCount: startSequence.count)
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

    func testApply() {
        var array = [0, 1, 2, 3, 4]
        var change = ArrayChange<Int>(initialCount: 5)
        change.add(.insert(10, at: 2))
        change.add(.remove(1, at: 1))
        change.add(.replace(4, at: 4, with: 20))

        change.apply(on: &array)

        XCTAssertEqual(array, [0, 10, 2, 3, 20])
    }

    func testDescription() {
        var change = ArrayChange<Int>(initialCount: 5)
        change.add(.insert(10, at: 2))
        change.add(.remove(1, at: 1))
        change.add(.replace(4, at: 4, with: 20))

        XCTAssertEqual(change.description, "ArrayChange<Int> initialCount: 5, 2 modifications")
        XCTAssertEqual(change.debugDescription, "GlueKit.ArrayChange<Swift.Int> initialCount: 5, 2 modifications")
    }

    func testRemovingEqualChanges() {
        var change = ArrayChange<Int>(initialCount: 5)
        change.add(.remove(1, at: 1))
        change.add(.insert(1, at: 1))
        change.add(.replace(4, at: 4, with: 40))

        XCTAssertEqual(change.modifications, [.replace(1, at: 1, with: 1), .replace(4, at: 4, with: 40)])
        XCTAssertEqual(change.removingEqualChanges().modifications, [.replace(4, at: 4, with: 40)])
    }

}
