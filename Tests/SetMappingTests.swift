//
//  SetMappingTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-05.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
import GlueKit

private class Book: Hashable {
    let title: StringVariable
    let authors: SetVariable<String>
    let chapters: ArrayVariable<String>

    init(_ title: String, authors: Set<String> = [], chapters: [String] = []) {
        self.title = .init(title)
        self.authors = .init(authors)
        self.chapters = .init(chapters)
    }

    var hashValue: Int { return ObjectIdentifier(self).hashValue }
    static func ==(a: Book, b: Book) -> Bool { return a === b }
}

class SetMappingTests: XCTestCase {
    func test_injectiveMap() {
        let set = SetVariable<Int>([0, 2, 3])
        let mappedSet = set.injectiveMap { "\($0)" }

        XCTAssertTrue(mappedSet.isBuffered)
        XCTAssertEqual(mappedSet.count, 3)
        XCTAssertEqual(mappedSet.value, Set(["0", "2", "3"]))
        XCTAssertEqual(mappedSet.contains("0"), true)
        XCTAssertEqual(mappedSet.contains("1"), false)
        XCTAssertEqual(mappedSet.isSubset(of: []), false)
        XCTAssertEqual(mappedSet.isSubset(of: ["3", "4", "5"]), false)
        XCTAssertEqual(mappedSet.isSubset(of: ["0", "2", "3"]), true)
        XCTAssertEqual(mappedSet.isSubset(of: ["0", "1", "2", "3"]), true)
        XCTAssertEqual(mappedSet.isSuperset(of: []), true)
        XCTAssertEqual(mappedSet.isSuperset(of: ["3"]), true)
        XCTAssertEqual(mappedSet.isSuperset(of: ["0", "2", "3"]), true)
        XCTAssertEqual(mappedSet.isSuperset(of: ["0", "1", "2", "3"]), false)
        XCTAssertEqual(mappedSet.isSuperset(of: ["1"]), false)

        let mock = MockSetObserver(mappedSet)
        mock.expecting("[]/[1]") { set.insert(1) }
        XCTAssertEqual(mappedSet.value, Set(["0", "1", "2", "3"]))
        mock.expecting("[1, 2]/[]") { set.subtract(Set([1, 2])) }
        XCTAssertEqual(mappedSet.value, Set(["0", "3"]))
    }

    func test_map_injectiveValue() {
        let set = SetVariable<Int>([0, 2, 3])
        let mappedSet = set.map { "\($0)" }

        XCTAssertFalse(mappedSet.isBuffered)
        XCTAssertEqual(mappedSet.count, 3)
        XCTAssertEqual(mappedSet.value, Set(["0", "2", "3"]))
        XCTAssertEqual(mappedSet.contains("0"), true)
        XCTAssertEqual(mappedSet.contains("1"), false)
        XCTAssertEqual(mappedSet.isSubset(of: []), false)
        XCTAssertEqual(mappedSet.isSubset(of: ["3", "4", "5"]), false)
        XCTAssertEqual(mappedSet.isSubset(of: ["0", "2", "3"]), true)
        XCTAssertEqual(mappedSet.isSubset(of: ["0", "1", "2", "3"]), true)
        XCTAssertEqual(mappedSet.isSuperset(of: []), true)
        XCTAssertEqual(mappedSet.isSuperset(of: ["3"]), true)
        XCTAssertEqual(mappedSet.isSuperset(of: ["0", "2", "3"]), true)
        XCTAssertEqual(mappedSet.isSuperset(of: ["0", "1", "2", "3"]), false)
        XCTAssertEqual(mappedSet.isSuperset(of: ["1"]), false)

        let mock = MockSetObserver(mappedSet)
        mock.expecting("[]/[1]") { set.insert(1) }
        XCTAssertEqual(mappedSet.value, Set(["0", "1", "2", "3"]))
        mock.expecting("[1, 2]/[]") { set.subtract(Set([1, 2])) }
        XCTAssertEqual(mappedSet.value, Set(["0", "3"]))
    }

    func test_map_noninjectiveValue() {
        let set = SetVariable<Int>([0, 2, 3, 4, 8, 9])
        let mappedSet = set.map { $0 / 2 }

        XCTAssertEqual(mappedSet.value, [0, 1, 2, 4])

        let mock = MockSetObserver(mappedSet)
        mock.expectingNothing { set.insert(1) }
        XCTAssertEqual(mappedSet.value, [0, 1, 2, 4])
        mock.expecting("[2]/[]") { set.remove(4) }
        XCTAssertEqual(mappedSet.value, [0, 1, 4])
        mock.expectingNothing { set.remove(3) }
        XCTAssertEqual(mappedSet.value, [0, 1, 4])
    }

    func test_map_valueField() {
        let b1 = Book("foo")
        let b2 = Book("bar")
        let b3 = Book("baz")

        let books: SetVariable<Book> = [b1, b2, b3]
        let titles = books.map { $0.title }

        XCTAssertEqual(titles.value, ["foo", "bar", "baz"])

        let mock = MockSetObserver(titles)

        let b4 = Book("fred")
        mock.expecting("[]/[fred]") {
            books.insert(b4)
        }
        XCTAssertEqual(titles.value, ["foo", "bar", "baz", "fred"])

        mock.expecting("[bar]/[]") {
            books.remove(b2)
        }
        XCTAssertEqual(titles.value, ["foo", "baz", "fred"])

        mock.expecting("[baz]/[bazaar]") { b3.title.value = "bazaar" }
        XCTAssertEqual(titles.value, ["foo", "bazaar", "fred"])

        mock.expectingNothing { b3.title.value = "bazaar" }
        XCTAssertEqual(titles.value, ["foo", "bazaar", "fred"])

        mock.expectingNothing { b2.title.value = "xyzzy" } // b2 isn't in books
        XCTAssertEqual(titles.value, ["foo", "bazaar", "fred"])

        mock.expecting("[foo]/[xyzzy]") { b1.title.value = "xyzzy" }
        XCTAssertEqual(titles.value, ["xyzzy", "bazaar", "fred"])

        mock.expectingNothing { books.insert(b2) }
        mock.expectingNothing { books.remove(b1) }
        XCTAssertEqual(titles.value, ["xyzzy", "bazaar", "fred"])

        mock.expecting("[xyzzy]/[]") { books.remove(b2) }
        XCTAssertEqual(titles.value, ["bazaar", "fred"])

        mock.expecting("[fred]/[fuzzy]") { b4.title.value = "fuzzy" }
        XCTAssertEqual(titles.value, ["bazaar", "fuzzy"])

        mock.expecting("[bazaar]/[]") { b3.title.value = "fuzzy" }
        XCTAssertEqual(titles.value, ["fuzzy"])
    }

    func test_flatMap_setField() {
        let b1 = Book("1", authors: ["a", "b", "c"])
        let b2 = Book("2", authors: ["a"])
        let b3 = Book("3", authors: ["b", "d"])

        let books: SetVariable<Book> = [b1, b2, b3]
        let authors = books.flatMap { $0.authors }

        XCTAssertEqual(authors.value, ["a", "b", "c", "d"])

        let mock = MockSetObserver(authors)

        let b4 = Book("4", authors: ["b", "c", "e"])
        mock.expecting("[]/[e]") { books.insert(b4) }
        XCTAssertEqual(authors.value, ["a", "b", "c", "d", "e"])

        mock.expectingNothing { books.remove(b1) }
        XCTAssertEqual(authors.value, ["a", "b", "c", "d", "e"])

        mock.expecting("[c]/[]") { b4.authors.remove("c") }
        XCTAssertEqual(authors.value, ["a", "b", "d", "e"])

        mock.expecting("[]/[c]") { b4.authors.insert("c") }
        XCTAssertEqual(authors.value, ["a", "b", "c", "d", "e"])

        mock.expecting("[a]/[f]") { b2.authors.value = ["f"] }
        XCTAssertEqual(authors.value, ["b", "c", "d", "e", "f"])

        mock.expecting("[d]/[]") { books.remove(b3) }
        XCTAssertEqual(authors.value, ["b", "c", "e", "f"])

        mock.expecting("[f]/[]") { books.remove(b2) }
        XCTAssertEqual(authors.value, ["b", "c", "e"])
    }

    func test_flatMap_arrayField() {
        let b1 = Book("1", chapters: ["a", "b", "c"])
        let b2 = Book("2", chapters: ["a"])
        let b3 = Book("3", chapters: ["b", "d"])

        let books: SetVariable<Book> = [b1, b2, b3]
        // It isn't very useful to make a set of chapters from several books, but let's do that anyway.
        let chapters = books.flatMap { $0.chapters }

        XCTAssertEqual(chapters.value, ["a", "b", "c", "d"])

        let mock = MockSetObserver(chapters)

        let b4 = Book("4", chapters: ["b", "c", "e"])
        mock.expecting("[]/[e]") { books.insert(b4) }
        XCTAssertEqual(chapters.value, ["a", "b", "c", "d", "e"])

        mock.expectingNothing { books.remove(b1) }
        XCTAssertEqual(chapters.value, ["a", "b", "c", "d", "e"])

        mock.expecting("[c]/[]") { _ = b4.chapters.remove(at: 1) } // b4.chapters was bce
        XCTAssertEqual(chapters.value, ["a", "b", "d", "e"])

        mock.expecting("[]/[c]") { b4.chapters.insert("c", at: 1) } // b4.chapters was be
        XCTAssertEqual(chapters.value, ["a", "b", "c", "d", "e"])

        mock.expectingNothing { b4.chapters.value = ["e", "c", "b"] } // Reordering chapters has no effect on result set
        XCTAssertEqual(chapters.value, ["a", "b", "c", "d", "e"])

        mock.expecting("[a]/[f]") { b2.chapters.value = ["f"] }
        XCTAssertEqual(chapters.value, ["b", "c", "d", "e", "f"])

        mock.expecting("[d]/[]") { books.remove(b3) }
        XCTAssertEqual(chapters.value, ["b", "c", "e", "f"])

        mock.expecting("[f]/[]") { books.remove(b2) }
        XCTAssertEqual(chapters.value, ["b", "c", "e"])
    }

    func test_flatMap_sequence() {
        let b1 = Book("1", authors: ["a", "b", "c"])
        let b2 = Book("2", authors: ["a"])
        let b3 = Book("3", authors: ["b", "d"])

        let books: SetVariable<Book> = [b1, b2, b3]
        // In this variant, we extract the value of the authors field, so that we have a simple flatMap where the
        // transform closure just returns a sequence. This means that the resulting observable does not track changes
        // to the values of individual fields, which is normally a bad idea -- but for this test, it spares us from 
        // having to add a sequence-typed property to Book.
        let authors = books.flatMap { $0.authors.value }

        XCTAssertEqual(authors.value, ["a", "b", "c", "d"])

        let mock = MockSetObserver(authors)

        let b4 = Book("4", authors: ["b", "c", "e"])
        mock.expecting("[]/[e]") { books.insert(b4) }
        XCTAssertEqual(authors.value, ["a", "b", "c", "d", "e"])

        mock.expectingNothing { books.remove(b1) }
        XCTAssertEqual(authors.value, ["a", "b", "c", "d", "e"])

        mock.expecting("[d]/[]") { books.remove(b3) }
        XCTAssertEqual(authors.value, ["a", "b", "c", "e"])

        mock.expecting("[a]/[]") { books.remove(b2) }
        XCTAssertEqual(authors.value, ["b", "c", "e"])
    }

}
