//
//  ArrayModificationTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
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

func ==<Element: Equatable>(a: [ArrayModification<Element>], b: [ArrayModification<Element>]) -> Bool {
    return a.elementsEqual(b, by: ==)
}
func !=<Element: Equatable>(a: [ArrayModification<Element>], b: [ArrayModification<Element>]) -> Bool {
    return !(a == b)
}

func XCTAssertEqual<Element: Equatable>(_ a: [ArrayModification<Element>], _ b: [ArrayModification<Element>], file: StaticString = #file, line: UInt = #line) {
    if a != b {
        XCTFail("\(a) is not equal to \(b)", file: file, line: line)
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

    func testRemovingEqualChanges() {
        typealias M = ArrayModification<String>

        XCTAssertEqual(M.insert("foo", at: 1).removingEqualChanges(), [M.insert("foo", at: 1)])

        XCTAssertEqual(M.remove("foo", at: 1).removingEqualChanges(), [M.remove("foo", at: 1)])

        XCTAssertEqual(M.replace("foo", at: 1, with: "bar").removingEqualChanges(), [M.replace("foo", at: 1, with: "bar")])
        XCTAssertEqual(M.replace("foo", at: 1, with: "foo").removingEqualChanges(), [])

        XCTAssertEqual(M.replaceSlice(["foo"], at: 1, with: ["bar"]).removingEqualChanges(),
                       [M.replace("foo", at: 1, with: "bar")])
        XCTAssertEqual(M.replaceSlice(["foo", "bar"], at: 1, with: ["bar", "foo"]).removingEqualChanges(),
                       [M.replaceSlice(["foo", "bar"], at: 1, with: ["bar", "foo"])])
        XCTAssertEqual(M.replaceSlice(["foo", "bar", "baz"], at: 1, with: ["baz", "bar", "foo"]).removingEqualChanges(),
                       [M.replace("foo", at: 1, with: "baz"), M.replace("baz", at: 3, with: "foo")])
        XCTAssertEqual(M.replaceSlice(["foo", "bar", "baz"], at: 1, with: ["foo", "bar", "foo"]).removingEqualChanges(),
                       [M.replace("baz", at: 3, with: "foo")])
        XCTAssertEqual(M.replaceSlice(["foo", "bar", "baz"], at: 1, with: ["foo", "bar", "baz"]).removingEqualChanges(),
                       [])
    }

    func testEquality() {
        typealias M = ArrayModification<String>

        XCTAssertTrue(M.insert("foo", at: 1) == M.insert("foo", at: 1))
        XCTAssertFalse(M.insert("foo", at: 1) != M.insert("foo", at: 1))

        XCTAssertFalse(M.insert("foo", at: 1) == M.insert("bar", at: 1))
        XCTAssertFalse(M.insert("foo", at: 1) == M.insert("foo", at: 2))

        XCTAssertTrue(M.insert("foo", at: 1) == M.replaceSlice([], at: 1, with: ["foo"]))
    }

    func testIsIdentity() {
        typealias M = ArrayModification<String>

        XCTAssertFalse(M.insert("foo", at: 1).isIdentity)

        XCTAssertFalse(M.remove("foo", at: 1).isIdentity)

        XCTAssertFalse(M.replace("foo", at: 1, with: "bar").isIdentity)
        XCTAssertTrue(M.replace("foo", at: 1, with: "foo").isIdentity)

        XCTAssertFalse(M.replaceSlice(["foo", "bar"], at: 1, with: ["bar", "foo"]).isIdentity)
        XCTAssertFalse(M.replaceSlice(["foo", "bar"], at: 1, with: ["foo", "foo"]).isIdentity)
        XCTAssertTrue(M.replaceSlice(["foo", "bar"], at: 1, with: ["foo", "bar"]).isIdentity)
    }

    func testDescription() {
        typealias M = ArrayModification<String>

        XCTAssertEqual(M.insert("foo", at: 1).description, ".insert(foo, at: 1)")
        XCTAssertEqual(M.remove("foo", at: 1).description, ".remove(foo, at: 1)")
        XCTAssertEqual(M.replace("foo", at: 1, with: "bar").description, ".replace(foo, at: 1, with: bar)")
        XCTAssertEqual(M.replaceSlice(["foo", "bar"], at: 1, with: ["bar", "foo"]).description,
                       ".replaceSlice([foo, bar], at: 1, with: [bar, foo])")

        XCTAssertEqual(M.insert("foo", at: 1).debugDescription, ".insert(\"foo\", at: 1)")
        XCTAssertEqual(M.remove("foo", at: 1).debugDescription, ".remove(\"foo\", at: 1)")
        XCTAssertEqual(M.replace("foo", at: 1, with: "bar").debugDescription, ".replace(\"foo\", at: 1, with: \"bar\")")
        XCTAssertEqual(M.replaceSlice(["foo", "bar"], at: 1, with: ["bar", "foo"]).debugDescription,
                       ".replaceSlice([\"foo\", \"bar\"], at: 1, with: [\"bar\", \"foo\"])")
    }
}
