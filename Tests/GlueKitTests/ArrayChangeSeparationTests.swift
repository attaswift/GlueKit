//
//  ArrayChangeSeparationTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit

/// Generate an exhaustive list of array changes, each consisting of a sequence of at most 
/// `depth` range replacements that insert at most `maxInsertion` elements.
func generateArrayChanges(input: [Int], depth: Int, maxInsertion: Int, body: @escaping (ArrayChange<Int>) -> Void) {
    func insertionsAtLevel(_ level: Int) -> [[Int]] {
        // Returns an array of [], [30], [30, 31], ..., up to maxInsertionLength
        let s = 10 * level
        return (0...maxInsertion).map { (0..<$0).map { s + $0 } }
    }

    func recurse(level: Int, buffer: [Int], prefix: ArrayChange<Int>) {
        if level >= depth { return }
        for startIndex in buffer.startIndex...buffer.endIndex {
            for endIndex in startIndex...buffer.endIndex {
                let range = startIndex ..< endIndex

                if range.count > 0 {
                    // Move a slice
                    let slice = Array(buffer[range])
                    var b = buffer
                    b.removeSubrange(range)
                    for target in 0 ... buffer.count - range.count {
                        if target == startIndex { continue }
                        var next = b
                        next.insert(contentsOf: slice, at: target)
                        var change = prefix
                        change.add(ArrayModification.replaceSlice(slice, at: startIndex, with: []))
                        change.add(ArrayModification.replaceSlice([], at: target, with: slice))
                        body(change)
                        recurse(level: level + 1, buffer: next, prefix: change)
                    }
                }
                for insertion in insertionsAtLevel(level) {
                    if insertion.count == 0 && endIndex == startIndex {
                        // Skip replacing empty with empty
                        continue
                    }
                    var next = buffer
                    next.replaceSubrange(range, with: insertion)
                    let mod = ArrayModification.replaceSlice(Array(buffer[range]), at: startIndex, with: insertion)
                    let change = prefix.merged(with: ArrayChange(initialCount: buffer.count, modification: mod))
                    body(change)
                    recurse(level: level + 1, buffer: next, prefix: change)
                }
            }
        }
    }

    recurse(level: 0, buffer: input, prefix: ArrayChange<Int>(initialCount: input.count))
}

class ArrayChangeSeparationTests: XCTestCase {
    func testSimpleSeparation() {
        let input = [-1, -2]
        generateArrayChanges(input: input, depth: 3, maxInsertion: 2) { change in
            // We'll emulate UITableView's content update logic, feed it the change and see if we 
            // arrive at a result that matches the updated array.
            var output = input
            output.apply(change)

            var table = input
            for index in change.deletedIndices.reversed() {
                table.remove(at: index)
            }
            for index in change.insertedIndices {
                table.insert(output[index], at: index)
            }
            XCTAssertEqual(table, output)
        }
    }

    func testSeparation() {
        let input = [-1, -2, -3]
        generateArrayChanges(input: input, depth: 2, maxInsertion: 2) { change in
            // We'll emulate UITableView's content update logic, feed it the change and see if we
            // arrive at a result that matches the updated array.
            var output = input
            output.apply(change)

            let sep = change.separated()
            var table = input

            var deleted = sep.deleted
            var inserted = sep.inserted
            var moveTargets = IndexSet()
            var movedElements: [Int] = []

            for (old, new) in sep.moved.sorted(by: { $0.1 < $1.1 }) {
                moveTargets.insert(new)
                movedElements.append(table[old])
                deleted.insert(old)
            }
            inserted.formUnion(moveTargets)
            for index in deleted.reversed() {
                table.remove(at: index)
            }
            for index in inserted {
                if moveTargets.contains(index) {
                    table.insert(movedElements.removeFirst(), at: index)
                }
                else {
                    table.insert(output[index], at: index)
                }
            }
            XCTAssertEqual(table, output)
        }
    }
}
