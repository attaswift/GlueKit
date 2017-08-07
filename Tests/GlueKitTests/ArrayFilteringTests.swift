//
//  ArrayFilteringTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-09-27.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit

private class Book: Equatable, CustomStringConvertible {
    let id: String
    let title: Variable<String>

    init(id: String, title: String) {
        self.id = id
        self.title = Variable(title)
    }

    var description: String {
        return id
    }

    static func ==(a: Book, b: Book) -> Bool {
        return a.title.value == b.title.value
    }
}

class ArrayFilteringTests: XCTestCase {

    func test_filterOnPredicate_getters() {
        let array: ArrayVariable<Int> = [1, 3, 5, 6]

        let even = array.filter { $0 % 2 == 0 }

        XCTAssertFalse(even.isBuffered)
        XCTAssertEqual(even.count, 1)
        XCTAssertEqual(even[0], 6)
        XCTAssertEqual(even[0 ..< 1], ArraySlice([6]))
        XCTAssertEqual(even.value, [6])

        array.value = Array(0 ..< 10)
        XCTAssertEqual(even.count, 5)
        XCTAssertEqual(even.value, [0, 2, 4, 6, 8])

        array.remove(at: 3)
        XCTAssertEqual(even.count, 5)
        XCTAssertEqual(even.value, [0, 2, 4, 6, 8])

        array.remove(at: 3)
        XCTAssertEqual(even.count, 4)
        XCTAssertEqual(even.value, [0, 2, 6, 8])

        array.insert(10, at: 2)
        XCTAssertEqual(even.count, 5)
        XCTAssertEqual(even.value, [0, 10, 2, 6, 8])

        array[2] = 12
        XCTAssertEqual(even.count, 5)
        XCTAssertEqual(even.value, [0, 12, 2, 6, 8])

        array[2] = 11
        XCTAssertEqual(even.count, 4)
        XCTAssertEqual(even.value, [0, 2, 6, 8])

        array[2] = 9
        XCTAssertEqual(even.count, 4)
        XCTAssertEqual(even.value, [0, 2, 6, 8])

        array[2] = 10
        XCTAssertEqual(even.count, 5)
        XCTAssertEqual(even.value, [0, 10, 2, 6, 8])

        array.removeAll()
        XCTAssertEqual(even.count, 0)
        XCTAssertEqual(even.value, [])
    }

    func test_filterOnPredicate_updates() {
        let array: ArrayVariable<Int> = [0, 1, 2, 3, 4]

        let evenMembers = array.filter { $0 % 2 == 0 }
        let mock = MockArrayObserver<Int>(evenMembers)

        mock.expecting(["begin", "3.insert(6, at: 3)", "end"]) {
            array.insert(contentsOf: [5, 6, 7], at: 5)
        }

        mock.expecting(["begin", "4.replaceSlice([2, 4], at: 1, with: [])", "end"]) {
            array.removeSubrange(1 ..< 5)
        }
    }

    func test_filterOnObservableBool_getters() {
        let b1 = Book(id: "b1", title: "Winnie the Pooh")
        let b2 = Book(id: "b2", title: "The Color of Magic")
        let b3 = Book(id: "b3", title: "Structure and Interpretation of Computer Programs")
        let b4 = Book(id: "b4", title: "Numerical Recipes in C++")
        let array: ArrayVariable<Book> = [b1, b2, b3, b4]

        // Books with "of" in their title.
        let filtered = array.filter { $0.title.map { $0.lowercased().contains("of") } }

        XCTAssertEqual(filtered.isBuffered, false)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered[0], b2)
        XCTAssertEqual(filtered[1], b3)
        XCTAssertEqual(filtered[0 ..< 2], ArraySlice([b2, b3]))
        XCTAssertEqual(filtered.value, [b2, b3])

        let b5 = Book(id: "b5", title: "Of Mice and Men")
        array.append(b5)
        XCTAssertEqual(filtered.count, 3)
        XCTAssertEqual(filtered.value, [b2, b3, b5])

        array.remove(at: 1)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered.value, [b3, b5])

        b4.title.value = "The TeXbook"
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered.value, [b3, b5])

        b4.title.value = "House of Leaves"
        XCTAssertEqual(filtered.count, 3)
        XCTAssertEqual(filtered.value, [b3, b4, b5])

        b4.title.value = "Good Omens"
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered.value, [b3, b5])
    }

    func test_complex_updates() {
        let b1 = Book(id: "b1", title: "Winnie the Pooh")
        let b2 = Book(id: "b2", title: "The Color of Magic")
        let b3 = Book(id: "b3", title: "Structure and Interpretation of Computer Programs")
        let b4 = Book(id: "b4", title: "Numerical Recipes in C++")
        let array: ArrayVariable<Book> = [b1, b2, b3, b4]

        // Books with "of" in their title.
        let filtered = array.filter { $0.title.map { $0.lowercased().contains("of") } }
        let mock = MockArrayObserver<Book>(filtered)

        // filtered is [b2, b3]

        let b5 = Book(id: "b5", title: "Of Mice and Men")
        mock.expecting(["begin", "2.insert(b5, at: 2)", "end"]) {
            array.append(b5)
        }

        // filtered is [b2, b3, b5]

        mock.expecting(["begin", "3.remove(b2, at: 0)", "end"]) {
            _ = array.remove(at: 1)
        }

        // filtered is [b3, b5]

        mock.expecting(["begin", "end"]) {
            b4.title.value = "The TeXbook"
        }

        // filtered is [b3, b5]

        mock.expecting(["begin", "2.insert(b4, at: 1)", "end"]) {
            b4.title.value = "House of Leaves"
        }

        // filtered is [b3, b4, b5]

        mock.expecting(["begin", "3.remove(b4, at: 1)", "end"]) {
            b4.title.value = "Good Omens"
        }

        // filtered is [b3, b5]
    }

}
