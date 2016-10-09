//
//  SelectOperatorTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-06.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
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

        let mock = MockValueObserver(title)

        mock.expecting(.init(from: "FOO", to: "BAR")) {
            book.title.value = "bar"
        }
        XCTAssertEqual(title.value, "BAR")
    }

    func test_updatableValue() {
        let book = Book("foo")

        // This is a simple mapping that ignores that a book's title is itself observable.
        let title = book.title.map({ $0.uppercased() }, inverse: { $0.lowercased() })

        XCTAssertEqual(title.value, "FOO")

        let mock = MockValueObserver(title)

        mock.expecting(.init(from: "FOO", to: "BAR")) {
            book.title.value = "bar"
        }
        XCTAssertEqual(title.value, "BAR")

        mock.expecting(.init(from: "BAR", to: "BAZ")) {
            title.value = "BAZ"
        }
        XCTAssertEqual(title.value, "BAZ")
        XCTAssertEqual(book.title.value, "baz")
    }

    func test_sourceField() {
        let b1 = Book("foo")
        let v = Variable<Book>(b1)
        let titleChanges = v.map { $0.title.changes }

        var expected: [SimpleChange<String>] = []
        var actual: [SimpleChange<String>] = []
        let connection = titleChanges.connect { change in actual.append(change) }
        func expect(_ change: SimpleChange<String>? = nil, file: StaticString = #file, line: UInt = #line, body: () -> ()) {
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

        expect(SimpleChange(from: "foo", to: "bar")) {
            b1.title.value = "bar"
        }
        let b2 = Book("fred")
        expect() {
            v.value = b2
        }
        expect(SimpleChange(from: "fred", to: "barney")) {
            b2.title.value = "barney"
        }
        connection.disconnect()
    }

    func test_valueField() {
        let book = Book("book")

        let v = Variable<Book>(book)
        let title = v.map{ $0.title.map { $0.uppercased() } } // The title is updatable; uppercasing it makes it observable only.

        XCTAssertEqual(title.value, "BOOK")

        let mock = MockValueObserver(title)

        mock.expecting(.init(from: "BOOK", to: "UPDATED")) {
            book.title.value = "updated"
        }
        XCTAssertEqual(title.value, "UPDATED")

        let book2 = Book("other")
        mock.expecting(.init(from: "UPDATED", to: "OTHER")) {
            v.value = book2
        }
        XCTAssertEqual(title.value, "OTHER")
    }

    func test_updatableField() {
        let book = Book("book")

        let v = Variable<Book>(book)
        let title = v.map{$0.title}

        XCTAssertEqual(title.value, "book")

        let mock = MockValueObserver(title)

        mock.expecting(.init(from: "book", to: "updated")) {
            title.value = "updated"
        }
        XCTAssertEqual(title.value, "updated")
        XCTAssertEqual(book.title.value, "updated")

        let book2 = Book("other")
        mock.expecting(.init(from: "updated", to: "other")) {
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

        mock.expecting(3, .insert("D", at: 3)) {
            book.chapters.append("d")
        }
        XCTAssertEqual(chapters.value, ["A", "B", "C", "D"])

        let book2 = Book("other", chapters: ["10", "11"])
        mock.expecting(4, .replaceSlice(["A", "B", "C", "D"], at: 0, with: ["10", "11"])) {
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

        mock.expecting(3, .insert("4", at: 3)) {
            book.chapters.append("4")
        }
        XCTAssertEqual(chapters.value, ["1", "2", "3", "4"])

        mock.expecting(4, .remove("3", at: 2)) {
            _ = chapters.remove(at: 2)
        }
        XCTAssertEqual(chapters.value, ["1", "2", "4"])
        XCTAssertEqual(book.chapters.value, ["1", "2", "4"])

        let book2 = Book("other", chapters: ["10", "11"])
        mock.expecting(3, .replaceSlice(["1", "2", "4"], at: 0, with: ["10", "11"])) {
            v.value = book2
        }
        XCTAssertEqual(chapters.value, ["10", "11"])

        mock.expecting(2, .replace("10", at: 0, with: "20")) {
            chapters[0] = "20"
        }
        XCTAssertEqual(chapters.value, ["20", "11"])
        XCTAssertEqual(book2.chapters.value, ["20", "11"])

        mock.expecting(2, .insert("25", at: 1)) {
            chapters.insert("25", at: 1)
        }
        XCTAssertEqual(chapters.value, ["20", "25", "11"])
        XCTAssertEqual(book2.chapters.value, ["20", "25", "11"])

        mock.expecting(3, .replaceSlice(["25", "11"], at: 1, with: ["21", "22"])) {
            chapters[1 ..< 3] = ["21", "22"]
        }
        XCTAssertEqual(chapters.value, ["20", "21", "22"])
        XCTAssertEqual(book2.chapters.value, ["20", "21", "22"])

        mock.expecting(3, .replaceSlice(["20", "21", "22"], at: 0, with: ["foo", "bar"])) {
            chapters.value = ["foo", "bar"]
        }
        XCTAssertEqual(chapters.value, ["foo", "bar"])
        XCTAssertEqual(book2.chapters.value, ["foo", "bar"])
    }
}
