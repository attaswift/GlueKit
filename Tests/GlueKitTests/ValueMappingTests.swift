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
    let title: Variable<String>
    let authors: SetVariable<String>
    let chapters: ArrayVariable<String>

    init(_ title: String, authors: Set<String> = [], chapters: [String] = []) {
        self.title = .init(title)
        self.authors = .init(authors)
        self.chapters = .init(chapters)
    }
}

class ValueMappingTests: XCTestCase {
    func test_value() {
        let book = Book("foo")

        let title = book.title.map { $0.uppercased() }

        XCTAssertEqual(title.value, "FOO")

        let mock = MockValueUpdateSink(title)

        mock.expecting(["begin", "FOO -> BAR", "end"]) {
            book.title.value = "bar"
        }
        XCTAssertEqual(title.value, "BAR")
    }

    func test_updatableValue() {
        let book = Book("foo")

        // This is a simple mapping that ignores that a book's title is itself observable.
        let title = book.title.map({ $0.uppercased() }, inverse: { $0.lowercased() })

        XCTAssertEqual(title.value, "FOO")

        let mock = MockValueUpdateSink(title)

        mock.expecting(["begin", "FOO -> BAR", "end"]) {
            book.title.value = "bar"
        }
        XCTAssertEqual(title.value, "BAR")

        mock.expecting(["begin", "BAR -> BAZ", "end"]) {
            title.value = "BAZ"
        }
        XCTAssertEqual(title.value, "BAZ")
        XCTAssertEqual(book.title.value, "baz")
    }

    func test_sourceField() {
        let b1 = Book("foo")
        let v = Variable<Book>(b1)
        let titleChanges = v.map { $0.title.changes }

        var expected: [ValueChange<String>] = []
        var actual: [ValueChange<String>] = []
        let connection = titleChanges.subscribe { change in actual.append(change) }
        func expect(_ change: ValueChange<String>? = nil, file: StaticString = #file, line: UInt = #line, body: () -> ()) {
            if let change = change {
                expected.append(change)
            }
            body()
            if !expected.elementsEqual(actual, by: ==) {
                XCTFail("\(actual) is not equal to \(expected)", file: file, line: line)
            }
            expected = []
            actual = []
        }

        expect(ValueChange(from: "foo", to: "bar")) {
            b1.title.value = "bar"
        }
        let b2 = Book("fred")
        expect() {
            v.value = b2
        }
        expect(ValueChange(from: "fred", to: "barney")) {
            b2.title.value = "barney"
        }
        connection.disconnect()
    }

    func test_valueField() {
        let book = Book("book")

        let v = Variable<Book>(book)
        let title = v.map{ $0.title.map { $0.uppercased() } } // The title is updatable; uppercasing it makes it observable only.

        XCTAssertEqual(title.value, "BOOK")

        let mock = MockValueUpdateSink(title)

        mock.expecting(["begin", "BOOK -> UPDATED", "end"]) {
            book.title.value = "updated"
        }
        XCTAssertEqual(title.value, "UPDATED")

        let book2 = Book("other")
        mock.expecting(["begin", "UPDATED -> OTHER", "end"]) {
            v.value = book2
        }
        XCTAssertEqual(title.value, "OTHER")
    }

    func test_updatableField() {
        let book = Book("book")

        let v = Variable<Book>(book)
        let title = v.map{$0.title}

        XCTAssertEqual(title.value, "book")

        let mock = MockValueUpdateSink(title)

        mock.expecting(["begin", "book -> updated", "end"]) {
            title.value = "updated"
        }
        XCTAssertEqual(title.value, "updated")
        XCTAssertEqual(book.title.value, "updated")

        let book2 = Book("other")
        mock.expecting(["begin", "updated -> other", "end"]) {
            v.value = book2
        }
        XCTAssertEqual(title.value, "other")
    }

    func test_arrayField() {
        let book = Book("book", chapters: ["a", "b", "c"])
        let v = Variable<Book>(book)
        let chapters = v.map{ $0.chapters.map { $0.uppercased() } } // Uppercasing is there to remove updatability.

        XCTAssertEqual(chapters.isBuffered, false)
        XCTAssertEqual(chapters.count, 3)
        XCTAssertEqual(chapters.observableCount.value, 3)
        XCTAssertEqual(chapters.value, ["A", "B", "C"])
        XCTAssertEqual(chapters[0], "A")
        XCTAssertEqual(chapters[1 ..< 3], ["B", "C"])

        let mock = MockArrayObserver(chapters)

        mock.expecting(["begin", "3.insert(D, at: 3)", "end"]) {
            book.chapters.append("d")
        }
        XCTAssertEqual(chapters.value, ["A", "B", "C", "D"])

        let book2 = Book("other", chapters: ["10", "11"])
        mock.expecting(["begin", "4.replaceSlice([A, B, C, D], at: 0, with: [10, 11])", "end"]) {
            v.value = book2
        }
        XCTAssertEqual(chapters.value, ["10", "11"])
    }

    func test_updatableArrayField() {
        let book = Book("book", chapters: ["1", "2", "3"])
        let v = Variable<Book>(book)
        let chapters = v.map{$0.chapters}

        XCTAssertEqual(chapters.isBuffered, true)
        XCTAssertEqual(chapters.count, 3)
        XCTAssertEqual(chapters.observableCount.value, 3)
        XCTAssertEqual(chapters.value, ["1", "2", "3"])
        XCTAssertEqual(chapters[0], "1")
        XCTAssertEqual(chapters[1 ..< 3], ["2", "3"])

        let mock = MockArrayObserver(chapters)

        mock.expecting(["begin", "3.insert(4, at: 3)", "end"]) {
            book.chapters.append("4")
        }
        XCTAssertEqual(chapters.value, ["1", "2", "3", "4"])

        mock.expecting(["begin", "4.remove(3, at: 2)", "end"]) {
            _ = chapters.remove(at: 2)
        }
        XCTAssertEqual(chapters.value, ["1", "2", "4"])
        XCTAssertEqual(book.chapters.value, ["1", "2", "4"])

        let book2 = Book("other", chapters: ["10", "11"])
        mock.expecting(["begin", "3.replaceSlice([1, 2, 4], at: 0, with: [10, 11])", "end"]) {
            v.value = book2
        }
        XCTAssertEqual(chapters.value, ["10", "11"])

        mock.expecting(["begin", "2.replace(10, at: 0, with: 20)", "end"]) {
            chapters[0] = "20"
        }
        XCTAssertEqual(chapters.value, ["20", "11"])
        XCTAssertEqual(book2.chapters.value, ["20", "11"])

        mock.expecting(["begin", "2.insert(25, at: 1)", "end"]) {
            chapters.insert("25", at: 1)
        }
        XCTAssertEqual(chapters.value, ["20", "25", "11"])
        XCTAssertEqual(book2.chapters.value, ["20", "25", "11"])

        mock.expecting(["begin", "3.replaceSlice([25, 11], at: 1, with: [21, 22])", "end"]) {
            chapters[1 ..< 3] = ["21", "22"]
        }
        XCTAssertEqual(chapters.value, ["20", "21", "22"])
        XCTAssertEqual(book2.chapters.value, ["20", "21", "22"])

        mock.expecting(["begin", "3.replaceSlice([20, 21, 22], at: 0, with: [foo, bar])", "end"]) {
            chapters.value = ["foo", "bar"]
        }
        XCTAssertEqual(chapters.value, ["foo", "bar"])
        XCTAssertEqual(book2.chapters.value, ["foo", "bar"])
    }

    func test_setField() {
        let book = Book("book", authors: ["a", "b", "c"])
        let v = Variable<Book>(book)
        let authors = v.map { $0.authors.map { $0.uppercased() } } // Uppercased to lose updatability.

        XCTAssertEqual(authors.isBuffered, false)
        XCTAssertEqual(authors.count, 3)
        XCTAssertEqual(authors.observableCount.value, 3)
        XCTAssertEqual(authors.value, ["A", "B", "C"])
        XCTAssertEqual(authors.contains("A"), true)
        XCTAssertEqual(authors.contains("0"), false)
        XCTAssertEqual(authors.isSubset(of: ["A", "B", "C"]), true)
        XCTAssertEqual(authors.isSubset(of: ["A", "B", "C", "D"]), true)
        XCTAssertEqual(authors.isSubset(of: ["B", "C", "D"]), false)
        XCTAssertEqual(authors.isSuperset(of: ["A", "B", "C"]), true)
        XCTAssertEqual(authors.isSuperset(of: ["B", "C"]), true)
        XCTAssertEqual(authors.isSuperset(of: ["C", "D"]), false)

        let mock = MockSetObserver(authors)
        mock.expecting(["begin", "[]/[D]", "end"]) {
            book.authors.insert("d")
        }
        XCTAssertEqual(authors.value, ["A", "B", "C", "D"])
        mock.expecting(["begin", "[B]/[]", "end"]) {
            book.authors.remove("b")
        }
        XCTAssertEqual(authors.value, ["A", "C", "D"])

        mock.expecting(["begin", "[A, C, D]/[BARNEY, FRED]", "end"]) {
            v.value = Book("other", authors: ["fred", "barney"])
        }
        XCTAssertEqual(authors.value, ["FRED", "BARNEY"])
    }

    func test_updatableSetField() {
        let book = Book("book", authors: ["a", "b", "c"])
        let v = Variable<Book>(book)
        let authors = v.map{$0.authors}

        XCTAssertEqual(authors.isBuffered, true)
        XCTAssertEqual(authors.count, 3)
        XCTAssertEqual(authors.observableCount.value, 3)
        XCTAssertEqual(authors.value, ["a", "b", "c"])
        XCTAssertEqual(authors.contains("a"), true)
        XCTAssertEqual(authors.contains("0"), false)
        XCTAssertEqual(authors.isSubset(of: ["a", "b", "c"]), true)
        XCTAssertEqual(authors.isSubset(of: ["a", "b", "c", "d"]), true)
        XCTAssertEqual(authors.isSubset(of: ["b", "c", "d"]), false)
        XCTAssertEqual(authors.isSuperset(of: ["a", "b", "c"]), true)
        XCTAssertEqual(authors.isSuperset(of: ["b", "c"]), true)
        XCTAssertEqual(authors.isSuperset(of: ["c", "d"]), false)

        let mock = MockSetObserver(authors)
        mock.expecting(["begin", "[]/[d]", "end"]) {
            book.authors.insert("d")
        }
        XCTAssertEqual(authors.value, ["a", "b", "c", "d"])
        mock.expecting(["begin", "[b]/[]", "end"]) {
            book.authors.remove("b")
        }
        XCTAssertEqual(authors.value, ["a", "c", "d"])

        mock.expecting(["begin", "[]/[e]", "end"]) {
            authors.insert("e")
        }
        XCTAssertEqual(authors.value, ["a", "c", "d", "e"])
        XCTAssertEqual(book.authors.value, ["a", "c", "d", "e"])

        mock.expecting(["begin", "[c]/[]", "end"]) {
            authors.remove("c")
        }
        XCTAssertEqual(authors.value, ["a", "d", "e"])
        XCTAssertEqual(book.authors.value, ["a", "d", "e"])

        mock.expecting(["begin", "[]/[b, c]", "end"]) {
            authors.apply(SetChange(removed: [], inserted: ["b", "c"]))
        }
        XCTAssertEqual(authors.value, ["a", "b", "c", "d", "e"])
        XCTAssertEqual(book.authors.value, ["a", "b", "c", "d", "e"])

        mock.expecting(["begin", "[a, b, c, d, e]/[bar, foo]", "end"]) {
            authors.value = ["foo", "bar"]
        }
        XCTAssertEqual(authors.value, ["foo", "bar"])
        XCTAssertEqual(book.authors.value, ["foo", "bar"])

        mock.expecting(["begin", "[bar, foo]/[barney, fred]", "end"]) {
            v.value = Book("other", authors: ["fred", "barney"])
        }
        XCTAssertEqual(authors.value, ["fred", "barney"])
    }
}
