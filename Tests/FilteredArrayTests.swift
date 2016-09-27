//
//  FilteredArrayTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-09-27.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
import GlueKit

class MockArrayObserver<Element: Equatable>: SinkType {
    var context: [(StaticString, UInt)]
    var expectations: [(ArrayChange<Element>, StaticString, UInt)] = []

    init(file: StaticString = #file, line: UInt = #line) {
        self.context = [(file, line)]
    }

    var receive: (ArrayChange<Element>) -> Void {
        return { self.process($0) }
    }

    func expect(_ change: ArrayChange<Element>, file: StaticString = #file, line: UInt = #line) {
        expectations.append((change, file, line))
    }

    func expect<R>(_ change: ArrayChange<Element>, file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        self.context.append(file, line)
        defer { self.context.removeLast() }
        self.expect(change, file: file, line: line)
        return try body()
    }

    func expectFulfilled() {
        for (change, file, line) in expectations {
            XCTFail("Expectation \(change) not fulfilled", file: file, line: line)
        }
        expectations.removeAll()
    }

    func process(_ change: ArrayChange<Element>) {
        guard !expectations.isEmpty else {
            XCTFail("Unexpected change: \(change)", file: context.last!.0, line: context.last!.1)
            return
        }
        let expected = expectations.removeFirst()
        XCTAssertTrue(expected.0 == change, "Expected \(expected.0), got \(change)", file: expected.1, line: expected.2)
    }
}

private class Book: Equatable, CustomStringConvertible {
    let title: Variable<String>

    init(title: String) {
        self.title = Variable(title)
    }

    var description: String {
        return "Book(title: \"\(title.value)\")"
    }

    static func ==(a: Book, b: Book) -> Bool {
        return a.title.value == b.title.value
    }
}

class FilteredArrayTests: XCTestCase {

    func test_simple_valueAndCount() {
        let array: ArrayVariable<Int> = [1, 3, 5, 6]

        let evenMembers = array.filtered { $0 % 2 == 0 }
        XCTAssertEqual(evenMembers.count, 1)
        XCTAssertEqual(evenMembers.value, [6])

        array.value = Array(0 ..< 10)
        XCTAssertEqual(evenMembers.count, 5)
        XCTAssertEqual(evenMembers.value, [0, 2, 4, 6, 8])

        array.remove(at: 3)
        XCTAssertEqual(evenMembers.count, 5)
        XCTAssertEqual(evenMembers.value, [0, 2, 4, 6, 8])

        array.remove(at: 3)
        XCTAssertEqual(evenMembers.count, 4)
        XCTAssertEqual(evenMembers.value, [0, 2, 6, 8])

        array.insert(10, at: 2)
        XCTAssertEqual(evenMembers.count, 5)
        XCTAssertEqual(evenMembers.value, [0, 10, 2, 6, 8])

        array[2] = 12
        XCTAssertEqual(evenMembers.count, 5)
        XCTAssertEqual(evenMembers.value, [0, 12, 2, 6, 8])

        array[2] = 11
        XCTAssertEqual(evenMembers.count, 4)
        XCTAssertEqual(evenMembers.value, [0, 2, 6, 8])

        array[2] = 9
        XCTAssertEqual(evenMembers.count, 4)
        XCTAssertEqual(evenMembers.value, [0, 2, 6, 8])

        array[2] = 10
        XCTAssertEqual(evenMembers.count, 5)
        XCTAssertEqual(evenMembers.value, [0, 10, 2, 6, 8])

        array.removeAll()
        XCTAssertEqual(evenMembers.count, 0)
        XCTAssertEqual(evenMembers.value, [])
    }

    func test_simple_futureChanges() {
        let array: ArrayVariable<Int> = [0, 1, 2, 3, 4]

        let evenMembers = array.filtered { $0 % 2 == 0 }
        let mock = MockArrayObserver<Int>()
        let connection = evenMembers.futureChanges.connect(mock)

        mock.expect(ArrayChange(initialCount: 3, modification: .insert(6, at: 3)))
        array.insert(contentsOf: [5, 6, 7], at: 5)
        mock.expectFulfilled()

        mock.expect(ArrayChange(initialCount: 4, modification: .replaceSlice([2, 4], at: 1, with: [])))
        array.removeSubrange(1 ..< 5)
        mock.expectFulfilled()

        withExtendedLifetime(connection, {})
    }

    func test_complex_valueAndCount() {
        let b1 = Book(title: "Winnie the Pooh")
        let b2 = Book(title: "The Color of Magic")
        let b3 = Book(title: "Structure and Interpretation of Computer Programs")
        let b4 = Book(title: "Numerical Recipes in C++")
        let array: ArrayVariable<Book> = [b1, b2, b3, b4]

        // Books with "of" in their title.
        let filtered = array.filtered { $0.title.map { $0.lowercased().contains("of") } }
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered.value, [b2, b3])

        let b5 = Book(title: "Of Mice and Men")
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

    func test_complex_changes() {
        let b1 = Book(title: "Winnie the Pooh")
        let b2 = Book(title: "The Color of Magic")
        let b3 = Book(title: "Structure and Interpretation of Computer Programs")
        let b4 = Book(title: "Numerical Recipes in C++")
        let array: ArrayVariable<Book> = [b1, b2, b3, b4]

        let mock = MockArrayObserver<Book>()
        // Books with "of" in their title.
        let filtered = array.filtered { $0.title.map { $0.lowercased().contains("of") } }
        let connection = filtered.futureChanges.connect(mock)

        // filtered is [b2, b3]

        let b5 = Book(title: "Of Mice and Men")
        mock.expect(ArrayChange(initialCount: 2, modification: .insert(b5, at: 2))) {
            array.append(b5)
        }

        // filtered is [b2, b3, b5]

        mock.expect(ArrayChange(initialCount: 3, modification: .remove(b2, at: 0))) {
            _ = array.remove(at: 1)
        }

        // filtered is [b3, b5]

        b4.title.value = "The TeXbook"
        mock.expectFulfilled()

        // filtered is [b3, b5]

        mock.expect(ArrayChange(initialCount: 2, modification: .insert(b4, at: 1))) {
            b4.title.value = "House of Leaves"
        }

        // filtered is [b3, b4, b5]

        mock.expect(ArrayChange(initialCount: 3, modification: .remove(b4, at: 1))) {
            b4.title.value = "Good Omens"
        }

        // filtered is [b3, b5]

        withExtendedLifetime(connection) {}
    }

}
