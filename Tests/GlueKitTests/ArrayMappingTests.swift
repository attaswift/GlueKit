//
//  SelectOperatorTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-06.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

private class Book {
    let title: StringVariable
    let authors: ArrayVariable<String>

    init(_ title: String, _ authors: [String] = []) {
        self.title = .init(title)
        self.authors = .init(authors)
    }
}

class ArrayMappingTests: XCTestCase {

    func test_map_value() {
        let b1 = Book("foo")
        let b2 = Book("bar")
        let b3 = Book("baz")
        let books: ArrayVariable<Book> = [b1, b2, b3]

        // Ignoring observability like this isn't a good idea; if we change the title of a book, the titles
        // array won't get updated. However, it simplifies testing that we don't need to set up a read-only
        // property in our fixture.
        let titles = books.map{ $0.title.value }

        XCTAssertFalse(titles.isBuffered)
        XCTAssertEqual(titles.count, 3)
        XCTAssertEqual(titles.observableCount.value, 3)
        XCTAssertEqual(titles[0], "foo")
        XCTAssertEqual(titles[1 ..< 3], ArraySlice(["bar", "baz"]))

        XCTAssertEqual(titles.value, ["foo", "bar", "baz"])

        let mock = MockArrayObserver(titles)

        mock.expecting(["begin", "3.insert(fred, at: 3)", "end"]) {
            books.append(Book("fred"))
        }
        XCTAssertEqual(titles.value, ["foo", "bar", "baz", "fred"])
        mock.expecting(["begin", "4.remove(bar, at: 1)", "end"]) {
            _ = books.remove(at: 1)
        }
        XCTAssertEqual(titles.value, ["foo", "baz", "fred"])
        mock.expecting(["begin", "3.replace(foo, at: 0, with: fuzzy)", "end"]) {
            _ = books[0] = Book("fuzzy")
        }
        XCTAssertEqual(titles.value, ["fuzzy", "baz", "fred"])
        let barney = Book("barney")
        mock.expecting(["begin", "3.replaceSlice([baz, fred], at: 1, with: [barney])", "end"]) {
            _ = books.replaceSubrange(1 ..< 3, with: [barney])
        }
        XCTAssertEqual(titles.value, ["fuzzy", "barney"])

        // The observable doesn't know the title of a book may change, so it won't notice when we modify it.
        mock.expectingNothing {
            barney.title.value = "bazaar"
        }
        // However, this particular observable generates results on the fly, so the pull-based API includes the change.
        XCTAssertEqual(titles.value, ["fuzzy", "bazaar"])
    }

    func test_bufferedMap_observed() {
        let b1 = Book("foo")
        let b2 = Book("bar")
        let b3 = Book("baz")
        let books: ArrayVariable<Book> = [b1, b2, b3]

        // Ignoring observability like this isn't a good idea; if we change the title of a book, the titles
        // array won't get updated. However, it simplifies testing that we don't need to set up a read-only
        // property in our fixture.
        let titles = books.bufferedMap{ $0.title.value }

        XCTAssertTrue(titles.isBuffered)
        XCTAssertEqual(titles.count, 3)
        XCTAssertEqual(titles.observableCount.value, 3)
        XCTAssertEqual(titles[0], "foo")
        XCTAssertEqual(titles[1 ..< 3], ArraySlice(["bar", "baz"]))

        XCTAssertEqual(titles.value, ["foo", "bar", "baz"])

        let mock = MockArrayObserver(titles)

        mock.expecting(["begin", "3.insert(fred, at: 3)", "end"]) {
            books.append(Book("fred"))
        }
        XCTAssertEqual(titles.value, ["foo", "bar", "baz", "fred"])
        mock.expecting(["begin", "4.remove(bar, at: 1)", "end"]) {
            _ = books.remove(at: 1)
        }
        XCTAssertEqual(titles.value, ["foo", "baz", "fred"])
        mock.expecting(["begin", "3.replace(foo, at: 0, with: fuzzy)", "end"]) {
            _ = books[0] = Book("fuzzy")
        }
        XCTAssertEqual(titles.value, ["fuzzy", "baz", "fred"])
        let barney = Book("barney")
        mock.expecting(["begin", "3.replaceSlice([baz, fred], at: 1, with: [barney])", "end"]) {
            _ = books.replaceSubrange(1 ..< 3, with: [barney])
        }
        XCTAssertEqual(titles.value, ["fuzzy", "barney"])

        // The observable doesn't know the title of a book may change, so it won't notice when we modify it.
        mock.expectingNothing {
            barney.title.value = "bazaar"
        }
        // The observable is buffered, so if we pull a value out of it, it won't include the update.
        XCTAssertEqual(titles.value, ["fuzzy", "barney"])
    }

    func test_bufferedMap_unobserved() {
        let b1 = Book("foo")
        let b2 = Book("bar")
        let b3 = Book("baz")
        let books: ArrayVariable<Book> = [b1, b2, b3]

        let titles = books.bufferedMap{ $0.title.value }

        // If the buffered map is not observed, it runs a differed code path, so test that as well.
        books.append(Book("fred"))
        XCTAssertEqual(titles.value, ["foo", "bar", "baz", "fred"])
        _ = books.remove(at: 1)
        XCTAssertEqual(titles.value, ["foo", "baz", "fred"])
        _ = books[0] = Book("fuzzy")
        XCTAssertEqual(titles.value, ["fuzzy", "baz", "fred"])
        let barney = Book("barney")
        _ = books.replaceSubrange(1 ..< 3, with: [barney])
        XCTAssertEqual(titles.value, ["fuzzy", "barney"])

        // The observable doesn't know the title of a book may change, so it won't notice when we modify it.
        barney.title.value = "bazaar"
        // The observable is buffered, so if we pull a value out of it, it won't include the update.
        XCTAssertEqual(titles.value, ["fuzzy", "barney"])
    }

    func test_map_valueField() {
        let b1 = Book("foo")
        let b2 = Book("bar")
        let b3 = Book("baz")
        let books: ArrayVariable<Book> = [b1, b2, b3]

        let titles = books.map{$0.title}

        XCTAssertFalse(titles.isBuffered)
        XCTAssertEqual(titles.count, 3)
        XCTAssertEqual(titles[0], "foo")
        XCTAssertEqual(titles[1 ..< 3], ArraySlice(["bar", "baz"]))

        XCTAssertEqual(titles.value, ["foo", "bar", "baz"])

        let mock = MockArrayObserver(titles)

        let b4 = Book("fred")
        mock.expecting(["begin", "3.insert(fred, at: 3)", "end"]) {
            books.append(b4)
        }
        XCTAssertEqual(titles.value, ["foo", "bar", "baz", "fred"])
        mock.expecting(["begin", "4.remove(bar, at: 1)", "end"]) {
            _ = books.remove(at: 1)
        }
        XCTAssertEqual(titles.value, ["foo", "baz", "fred"])
        mock.expecting(["begin", "3.replace(baz, at: 1, with: bazaar)", "end"]) {
            b3.title.value = "bazaar"
        }
        XCTAssertEqual(titles.value, ["foo", "bazaar", "fred"])
    }

    func test_flatMap_arrayField() {
        let b1 = Book("foo", ["a", "b", "c"])
        let b2 = Book("bar", ["b", "d"])
        let b3 = Book("baz", ["a"])
        let b4 = Book("zoo", [])
        let books: ArrayVariable<Book> = [b1, b2, b3, b4]

        let authors = books.flatMap{$0.authors}

        XCTAssertEqual(authors.isBuffered, false)
        XCTAssertEqual(authors.value, [
            /*b1*/ "a", "b", "c",
            /*b2*/ "b", "d",
            /*b3*/ "a",
            /*b4*/
        ])
        XCTAssertEqual(authors.count, 6)
        XCTAssertEqual(authors[0], "a")
        XCTAssertEqual(authors[4], "d")
        XCTAssertEqual(authors[2..<4], ArraySlice(["c", "b"]))

        func checkSlices(file: StaticString = #file, line: UInt = #line) {
            let value = authors.value
            for i in 0 ..< authors.count {
                for j in i ..< authors.count {
                    XCTAssertEqual(authors[i ..< j], value[i ..< j], file: file, line: line)
                }
            }
        }

        checkSlices()

        let mock = MockArrayObserver(authors)

        let b5 = Book("fred", ["e"])
        mock.expecting(["begin", "6.insert(e, at: 6)", "end"]) {
            books.append(b5)
        }
        XCTAssertEqual(authors.value, [
            /*b1*/ "a", "b", "c",
            /*b2*/ "b", "d",
            /*b3*/ "a",
            /*b4*/
            /*b5*/ "e"
        ])
        checkSlices()

        mock.expecting(["begin", "7.replaceSlice([b, d], at: 3, with: [])", "end"]) {
            _ = books.remove(at: 1) // b2
        }
        XCTAssertEqual(authors.value, [
            /*b1*/ "a", "b", "c",
            /*b3*/ "a",
            /*b4*/
            /*b5*/ "e"
        ])
        checkSlices()

        mock.expecting(["begin", "5.replaceSlice([], at: 0, with: [b, d])", "end"]) {
            books.insert(b2, at: 0)
        }
        XCTAssertEqual(authors.value, [
            /*b2*/ "b", "d",
            /*b1*/ "a", "b", "c",
            /*b3*/ "a",
            /*b4*/
            /*b5*/ "e"
        ])
        checkSlices()

        mock.expecting(["begin", "7.insert(*, at: 1)", "end"]) {
            b2.authors.insert("*", at: 1)
        }
        XCTAssertEqual(authors.value, [
            /*b2*/ "b", "*", "d",
            /*b1*/ "a", "b", "c",
            /*b3*/ "a",
            /*b4*/
            /*b5*/ "e"
        ])
        checkSlices()

        mock.expecting(["begin", "8.replace(*, at: 1, with: f)", "end"]) {
            b2.authors[1] = "f"
        }
        XCTAssertEqual(authors.value, [
            /*b2*/ "b", "f", "d",
            /*b1*/ "a", "b", "c",
            /*b3*/ "a",
            /*b4*/
            /*b5*/ "e"
        ])
        checkSlices()

        mock.expecting(["begin", "8.insert(g, at: 8)", "end"]) {
            b5.authors.append("g")
        }
        XCTAssertEqual(authors.value, [
            /*b2*/ "b", "f", "d",
            /*b1*/ "a", "b", "c",
            /*b3*/ "a",
            /*b4*/
            /*b5*/ "e", "g"
        ])
        checkSlices()

        // Remove all authors from each book, one by one.

        mock.expecting(["begin", "9.remove(a, at: 6)", "end"]) {
            b3.authors.value = []
        }
        XCTAssertEqual(authors.value, [
            /*b2*/ "b", "f", "d",
            /*b1*/ "a", "b", "c",
            /*b3*/
            /*b4*/
            /*b5*/ "e", "g"
        ])
        checkSlices()

        mock.expecting(["begin", "8.replaceSlice([a, b, c], at: 3, with: [])", "end"]) {
            b1.authors.value = []
        }
        XCTAssertEqual(authors.value, [
            /*b2*/ "b", "f", "d",
            /*b1*/
            /*b3*/
            /*b4*/
            /*b5*/ "e", "g"
        ])
        checkSlices()

        mock.expecting(["begin", "5.replaceSlice([], at: 5, with: [b, f, d, e, g])", "end"]) {
            books.append(contentsOf: books.value)
        }
        XCTAssertEqual(authors.value, [
            /*b2*/ "b", "f", "d",
            /*b1*/
            /*b3*/
            /*b4*/
            /*b5*/ "e", "g",
            /*b2*/ "b", "f", "d",
            /*b1*/
            /*b3*/
            /*b4*/
            /*b5*/ "e", "g"
        ])
        checkSlices()

        mock.expectingOneOf([
            ["begin", "10.replaceSlice([b, f, d], at: 0, with: [])", "7.replaceSlice([b, f, d], at: 2, with: [])", "end"],
            ["begin", "10.replaceSlice([b, f, d], at: 5, with: [])", "7.replaceSlice([b, f, d], at: 0, with: [])", "end"]
        ]) {
            b2.authors.value = []
        }
        XCTAssertEqual(authors.value, [
            /*b2*/
            /*b1*/
            /*b3*/
            /*b4*/
            /*b5*/ "e", "g",
            /*b2*/
            /*b1*/
            /*b3*/
            /*b4*/
            /*b5*/ "e", "g"
        ])
        checkSlices()

        mock.expecting(["begin", "4.replaceSlice([e, g], at: 2, with: [])", "end"]) {
            books.removeSubrange(5 ..< 10)
        }
        XCTAssertEqual(authors.value, [
            /*b2*/
            /*b1*/
            /*b3*/
            /*b4*/
            /*b5*/ "e", "g"
        ])
        checkSlices()

        mock.expecting(["begin", "2.replaceSlice([e, g], at: 0, with: [])", "end"]) {
            b5.authors.value = []
        }
        XCTAssertEqual(authors.value, [
            // b2 b1 b3 b4 b5
        ])
        checkSlices()

        // At this point, no book has any author.

        mock.expecting(["begin", "end"]) {
            books.append(contentsOf: books.value)
        }
        XCTAssertEqual(authors.value, [
            // b2 b1 b3 b4 b5 b2 b1 b3 b4 b5
        ])
        checkSlices()

        mock.expectingOneOf([
            ["begin", "0.replaceSlice([], at: 0, with: [3a, 3b])", "2.replaceSlice([], at: 0, with: [3a, 3b])", "end"],
            ["begin", "0.replaceSlice([], at: 0, with: [3a, 3b])", "2.replaceSlice([], at: 2, with: [3a, 3b])", "end"],
        ]) {
            b3.authors.value = ["3a", "3b"]
        }
        XCTAssertEqual(authors.value, [
            /*b2*/
            /*b1*/
            /*b3*/ "3a", "3b",
            /*b4*/
            /*b5*/
            /*b2*/
            /*b1*/
            /*b3*/ "3a", "3b",
            /*b4*/
            /*b5*/
        ])
        checkSlices()

        mock.expectingOneOf([
            ["begin", "4.insert(1, at: 0)", "5.insert(1, at: 3)", "end"],
            ["begin", "4.insert(1, at: 2)", "5.insert(1, at: 0)", "end"],
        ]) {
            b1.authors.value = ["1"]
        }
        XCTAssertEqual(authors.value, [
            /*b2*/
            /*b1*/ "1",
            /*b3*/ "3a", "3b",
            /*b4*/
            /*b5*/
            /*b2*/
            /*b1*/ "1",
            /*b3*/ "3a", "3b",
            /*b4*/
            /*b5*/
        ])
        checkSlices()

        mock.expecting(["begin", "6.replaceSlice([3a, 3b], at: 4, with: [])", "end"]) {
            books.removeSubrange(7 ..< 10)
        }
        XCTAssertEqual(authors.value, [
            /*b2*/
            /*b1*/ "1",
            /*b3*/ "3a", "3b",
            /*b4*/
            /*b5*/
            /*b2*/
            /*b1*/ "1",
        ])
        checkSlices()

        mock.expecting(["begin", "4.insert(5a, at: 3)", "end"]) {
            b5.authors.append("5a")
        }
        XCTAssertEqual(authors.value, [
            /*b2*/
            /*b1*/ "1",
            /*b3*/ "3a", "3b",
            /*b4*/
            /*b5*/ "5a",
            /*b2*/
            /*b1*/ "1",
        ])
        checkSlices()

        mock.expecting(["begin", "5.insert(5b, at: 4)", "end"]) {
            b5.authors.append("5b")
        }
        XCTAssertEqual(authors.value, [
            /*b2*/
            /*b1*/ "1",
            /*b3*/ "3a", "3b",
            /*b4*/
            /*b5*/ "5a", "5b",
            /*b2*/
            /*b1*/ "1",
        ])
        checkSlices()

        mock.expectingOneOf([
            ["begin", "6.insert(2, at: 0)", "7.insert(2, at: 6)", "end"],
            ["begin", "6.insert(2, at: 5)", "7.insert(2, at: 0)", "end"],
        ]) {
            b2.authors.append("2")
        }
        XCTAssertEqual(authors.value, [
            /*b2*/ "2",
            /*b1*/ "1",
            /*b3*/ "3a", "3b",
            /*b4*/
            /*b5*/ "5a", "5b",
            /*b2*/ "2",
            /*b1*/ "1",
        ])
        checkSlices()

        mock.expecting(["begin", "8.remove(2, at: 6)", "end"]) {
            _ = books.remove(at: 5) // b2
        }
        XCTAssertEqual(authors.value, [
            /*b2*/ "2",
            /*b1*/ "1",
            /*b3*/ "3a", "3b",
            /*b4*/
            /*b5*/ "5a", "5b",
            /*b1*/ "1",
        ])
        checkSlices()

        mock.expecting(["begin", "7.remove(1, at: 1)", "end"]) {
            _ = books.remove(at: 1) // b1
        }
        XCTAssertEqual(authors.value, [
            /*b2*/ "2",
            /*b3*/ "3a", "3b",
            /*b4*/
            /*b5*/ "5a", "5b",
            /*b1*/ "1",
        ])
        checkSlices()

        mock.expecting(["begin", "6.replaceSlice([5a, 5b], at: 3, with: [])", "end"]) {
            b5.authors.value = []
        }
        XCTAssertEqual(authors.value, [
            /*b2*/ "2",
            /*b3*/ "3a", "3b",
            /*b4*/
            /*b5*/
            /*b1*/ "1",
        ])
        checkSlices()

        mock.expecting(["begin", "4.remove(1, at: 3)", "end"]) {
            _ = books.removeLast() // b1
        }
        XCTAssertEqual(authors.value, [
            /*b2*/ "2",
            /*b3*/ "3a", "3b",
            /*b4*/
            /*b5*/
        ])
        checkSlices()

        mock.expecting(["begin", "end"]) {
            _ = books.removeLast() // b5
        }
        XCTAssertEqual(authors.value, [
            /*b2*/ "2",
            /*b3*/ "3a", "3b",
            /*b4*/
        ])
        checkSlices()

        mock.expecting(["begin", "3.remove(2, at: 0)", "end"]) {
            b2.authors.value = []
        }
        XCTAssertEqual(authors.value, [
            /*b2*/
            /*b3*/ "3a", "3b",
            /*b4*/
        ])
        checkSlices()

        mock.expecting(["begin", "end"]) {
            _ = books.removeFirst() // b2
        }
        XCTAssertEqual(authors.value, [
            /*b3*/ "3a", "3b",
            /*b4*/
        ])
        checkSlices()

        mock.expecting(["begin", "end"]) {
            _ = books.removeLast() // b4
        }
        XCTAssertEqual(authors.value, [
            /*b3*/ "3a", "3b",
        ])
        checkSlices()

        mock.expecting(["begin", "2.replaceSlice([3a, 3b], at: 0, with: [])", "end"]) {
            _ = books.removeLast() // b3
        }
        XCTAssertEqual(authors.value, [])
        checkSlices()
    }
}

