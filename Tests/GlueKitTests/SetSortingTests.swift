//
//  SetSortingTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-05.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit

extension ArrayModification {
    fileprivate func dumped() -> String {
        switch self {
        case .insert(let e, at: let i):
            return "insert(\(e), at: \(i))"
        case .remove(let e, at: let i):
            return "remove(\(e), at: \(i))"
        case .replace(let old, at: let i, with: let new):
            return "replace(\(old), at: \(i), with: \(new))"
        case .replaceSlice(let old, at: let i, with: let new):
            let o = old.map { "\($0)" }.joined(separator: ", ")
            let n = new.map { "\($0)" }.joined(separator: ", ")
            return "replaceSlice([\(o)], at: \(i), with: [\(n)])"
        }
    }
}

extension ArrayChange {
    fileprivate func dumped() -> String {
        return modifications.lazy.map { $0.dumped() }.joined(separator: ", ")
    }
}

private class Book: Hashable, CustomStringConvertible {
    let title: StringVariable

    init(_ title: String) { self.title = .init(title) }

    var hashValue: Int { return ObjectIdentifier(self).hashValue }
    var description: String { return "Book(\(title.value))" }
    static func ==(a: Book, b: Book) -> Bool { return a === b }
}

class SetSortingTests: XCTestCase {
    func test_sortedSetUsingIdentityTransform() {
        let set = SetVariable<Int>([0, 2, 3, 4, 8, 9])
        let sortedSet = set.sorted()

        XCTAssertEqual(sortedSet.value, [0, 2, 3, 4, 8, 9])
        XCTAssertEqual(sortedSet.isBuffered, false)
        XCTAssertEqual(sortedSet.count, 6)
        XCTAssertEqual(sortedSet[0], 0)
        XCTAssertEqual(sortedSet[1], 2)
        XCTAssertEqual(sortedSet[2 ..< 4], ArraySlice([3, 4]))

        var actualChanges: [String] = []
        var expectedChanges: [String] = []
        let connection = sortedSet.changes.subscribe { change in
            actualChanges.append(change.dumped())
        }

        set.insert(1)
        XCTAssertEqual(sortedSet.value, [0, 1, 2, 3, 4, 8, 9])
        expectedChanges.append("insert(1, at: 1)")
        XCTAssertEqual(actualChanges, expectedChanges)

        set.remove(3)
        XCTAssertEqual(sortedSet.value, [0, 1, 2, 4, 8, 9])
        expectedChanges.append("remove(3, at: 3)")
        XCTAssertEqual(actualChanges, expectedChanges)

        set.formUnion([3, 5, 6])
        XCTAssertEqual(sortedSet.value, [0, 1, 2, 3, 4, 5, 6, 8, 9])
        expectedChanges.append("insert(3, at: 3), replaceSlice([], at: 5, with: [5, 6])")
        XCTAssertEqual(actualChanges, expectedChanges)

        connection.disconnect()
    }

    func test_sortedSetInReverse() {
        let set = SetVariable<Int>([0, 2, 3, 4, 8, 9])
        let sortedSet = set.sorted(by: >)

        XCTAssertEqual(sortedSet.value, [9, 8, 4, 3, 2, 0])

        var actualChanges: [String] = []
        var expectedChanges: [String] = []
        let connection = sortedSet.changes.subscribe { change in
            actualChanges.append(change.dumped())
        }

        set.insert(1)
        XCTAssertEqual(sortedSet.value, [9, 8, 4, 3, 2, 1, 0])
        expectedChanges.append("insert(1, at: 5)")
        XCTAssertEqual(actualChanges, expectedChanges)

        set.remove(3)
        XCTAssertEqual(sortedSet.value, [9, 8, 4, 2, 1, 0])
        expectedChanges.append("remove(3, at: 3)")
        XCTAssertEqual(actualChanges, expectedChanges)

        set.formUnion([3, 5, 6])
        XCTAssertEqual(sortedSet.value, [9, 8, 6, 5, 4, 3, 2, 1, 0])
        expectedChanges.append("replaceSlice([], at: 2, with: [6, 5]), insert(3, at: 5)")
        XCTAssertEqual(actualChanges, expectedChanges)

        connection.disconnect()
    }


    func test_sortedSetUsingNoninjectiveTransform() {
        let set = SetVariable<Int>([0, 2, 3, 4, 8, 9])
        let sortedSet = set.sortedMap { $0 / 2 }

        XCTAssertEqual(sortedSet.value, [0, 1, 2, 4])

        var actualChanges: [String] = []
        var expectedChanges: [String] = []
        let connection = sortedSet.changes.subscribe { change in
            actualChanges.append(change.dumped())
        }

        set.remove(2)
        XCTAssertEqual(sortedSet.value, [0, 1, 2, 4])
        XCTAssertEqual(actualChanges, expectedChanges) // No change expected (2 and 3 both mapped to 1).

        set.remove(3)
        XCTAssertEqual(sortedSet.value, [0, 2, 4])
        expectedChanges.append("remove(1, at: 1)")
        XCTAssertEqual(actualChanges, expectedChanges)

        set.insert(5)
        XCTAssertEqual(sortedSet.value, [0, 2, 4])
        XCTAssertEqual(actualChanges, expectedChanges) // No change expected (4 already mapped to 2).

        connection.disconnect()
    }

    func test_sortedSetUsingObservableTransform() {
        let b1 = Book("foo")
        let b2 = Book("bar")
        let b3 = Book("baz")
        let b4 = Book("fred")
        let books = SetVariable<Book>([b1, b2, b3])
        let sortedTitles = books.sortedMap {$0.title}

        XCTAssertEqual(sortedTitles.isBuffered, false)
        XCTAssertEqual(sortedTitles.value, ["bar", "baz", "foo"])
        XCTAssertEqual(sortedTitles.count, 3)
        XCTAssertEqual(sortedTitles[0], "bar")
        XCTAssertEqual(sortedTitles[1], "baz")
        XCTAssertEqual(sortedTitles[1 ..< 3], ArraySlice(["baz", "foo"]))

        var actualChanges: [String] = []
        var expectedChanges: [String] = []
        let connection = sortedTitles.changes.subscribe { change in
            actualChanges.append(change.dumped())
        }

        books.insert(b4)
        XCTAssertEqual(sortedTitles.value, ["bar", "baz", "foo", "fred"])
        expectedChanges.append("insert(fred, at: 3)")
        XCTAssertEqual(actualChanges, expectedChanges)


        books.subtract([b3, b4])
        XCTAssertEqual(sortedTitles.value, ["bar", "foo"])
        expectedChanges.append("remove(baz, at: 1), remove(fred, at: 2)")
        XCTAssertEqual(actualChanges, expectedChanges)

        b2.title.value = "barney"
        XCTAssertEqual(sortedTitles.value, ["barney", "foo"])
        expectedChanges.append("replace(bar, at: 0, with: barney)")
        XCTAssertEqual(actualChanges, expectedChanges)

        b3.title.value = "bazaar"
        XCTAssertEqual(sortedTitles.value, ["barney", "foo"])
        XCTAssertEqual(actualChanges, expectedChanges) // No change expected

        books.formUnion([b3, b4])
        XCTAssertEqual(sortedTitles.value, ["barney", "bazaar", "foo", "fred"])
        expectedChanges.append("insert(bazaar, at: 1), insert(fred, at: 3)")
        XCTAssertEqual(actualChanges, expectedChanges)

        b3.title.value = "xyzzy"
        XCTAssertEqual(sortedTitles.value, ["barney", "foo", "fred", "xyzzy"])
        expectedChanges.append("remove(bazaar, at: 1), insert(xyzzy, at: 3)")
        XCTAssertEqual(actualChanges, expectedChanges)

        b1.title.value = "xyzzy"
        XCTAssertEqual(sortedTitles.value, ["barney", "fred", "xyzzy"])
        expectedChanges.append("remove(foo, at: 1)")
        XCTAssertEqual(actualChanges, expectedChanges)

        books.remove(b3)
        XCTAssertEqual(sortedTitles.value, ["barney", "fred", "xyzzy"])
        XCTAssertEqual(actualChanges, expectedChanges) // No change expected (xyzzy had a multiplicity of 2).

        books.remove(b1)
        XCTAssertEqual(sortedTitles.value, ["barney", "fred"])
        expectedChanges.append("remove(xyzzy, at: 2)")
        XCTAssertEqual(actualChanges, expectedChanges)

        b2.title.value = "barney"
        XCTAssertEqual(sortedTitles.value, ["barney", "fred"])
        XCTAssertEqual(actualChanges, expectedChanges)

        connection.disconnect()
    }

    func test_sortedSetUsingObservableComparator() {
        let set = SetVariable(0..<5)
        let comparator = Variable<(Int, Int) -> Bool>(<)

        let sorted = set.sorted(by: comparator)
        XCTAssertEqual(sorted.value, [0, 1, 2, 3, 4])

        comparator.value = (>)

        XCTAssertEqual(sorted.value, [4, 3, 2, 1, 0])
    }
}
