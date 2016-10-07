//
//  ArrayChangeTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
import GlueKit

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
}
