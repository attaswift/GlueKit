//
//  RefListTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-08.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
@testable import GlueKit

private final class Fixture: RefListElement {
    var value: Int
    var refListLink = RefListLink<Fixture>()

    init(_ value: Int) { self.value = value }
}

class RefListTests: XCTestCase {
    private func verify(_ list: RefList<Fixture>, file: StaticString = #file, line: UInt = #line) {
        for i in 0 ..< list.count {
            let element = list[i]
            XCTAssertEqual(list.index(of: element), i, file: file, line: line)
        }
    }


    func test_emptyInitializer() {
        let list = RefList<Fixture>()
        XCTAssertTrue(list.isEmpty)
        XCTAssertEqual(Array(list).map { $0.value }, [])
        verify(list)
    }

    func test_initializerFromSequence() {
        let list = RefList<Fixture>((0 ..< 1000).map { Fixture($0) })
        XCTAssertFalse(list.isEmpty)
        XCTAssertEqual(Array(list).map { $0.value }, Array(0 ..< 1000))
        verify(list)
    }

    func test_basicOperations() {
        let list = RefList<Fixture>(order: 5)

        // Append even elements.
        for i in 0 ..< 50 {
            list.append(Fixture(2 * i))
            verify(list)
        }
        XCTAssertEqual(list.map { $0.value }, (0 ..< 50).map { 2 * $0 })

        // Insert odd elements.
        for i in 0 ..< 50 {
            list.insert(Fixture(2 * i + 1), at: 2 * i + 1)
            verify(list)
        }
        XCTAssertEqual(list.map { $0.value }, Array(0 ..< 100))

        // Look up elements.
        for i in 0 ..< 100 {
            let element = list[i]
            XCTAssertEqual(element.value, i)
        }

        // Remove elements from the start.
        for i in 0 ..< 50 {
            XCTAssertEqual(list.remove(at: 0).value, i)
            verify(list)
        }

        // Remove elements from the end.
        for i in (50 ..< 100).reversed() {
            XCTAssertEqual(list.remove(at: list.count - 1).value, i)
            verify(list)
        }
    }

    func test_remove() {
        let c = 30
        for removedIndex in 0 ..< c {
            let list = RefList<Fixture>(order: 5)
            let elements = (0 ..< c).map { Fixture($0) }
            list.append(contentsOf: elements)
            XCTAssertEqual(list.remove(at: removedIndex).value, removedIndex)
            verify(list)

            var expected = elements
            expected.remove(at: removedIndex)
            XCTAssertTrue(list.elementsEqual(expected, by: ===))
        }
    }

    func test_insertCollection() {
        let c = 30
        for insertionIndex in 0 ..< c {
            let list = RefList<Fixture>(order: 5)
            let origElements = (0 ..< c).map { Fixture($0) }
            list.append(contentsOf: origElements)

            let insertedElements = (0 ..< 10).map { Fixture(100 + $0) }
            list.insert(contentsOf: insertedElements, at: insertionIndex)
            verify(list)

            var expected = origElements
            expected.insert(contentsOf: insertedElements, at: insertionIndex)

            XCTAssertTrue(list.elementsEqual(expected, by: ===))
        }
    }

    func test_removeSubrange() {
        let c = 30
        for start in 0 ..< c {
            for end in start ..< c {
                let list = RefList<Fixture>(order: 5)
                let elements = (0 ..< c).map { Fixture($0) }
                list.append(contentsOf: elements)
                list.removeSubrange(start ..< end)
                verify(list)

                var expected = elements
                expected.removeSubrange(start ..< end)
                XCTAssertTrue(list.elementsEqual(expected, by: ===))
            }
        }
    }

    func test_replaceSubrange() {
        let c = 30
        for start in 0 ..< c {
            for end in start ..< c {
                for newRange in [0 ..< 0, 0 ..< 1, 0 ..< 10] {
                    let list = RefList<Fixture>(order: 5)
                    let elements = (0 ..< c).map { Fixture($0) }
                    list.append(contentsOf: elements)

                    let replacement = newRange.map { Fixture(100 + $0) }
                    list.replaceSubrange(start ..< end, with: replacement)
                    verify(list)

                    var expected = elements
                    expected.replaceSubrange(start ..< end, with: replacement)
                    XCTAssertTrue(list.elementsEqual(expected, by: ===))
                }
            }
        }
    }

    func test_subscript_setter() {
        let list = RefList<Fixture>(order: 5)
        list.append(contentsOf: (0 ..< 30).map { Fixture($0) })
        for i in 0 ..< 30 {
            list[i] = Fixture(2 * i)
            verify(list)
        }
        XCTAssertEqual(list.map { $0.value }, (0 ..< 30).map { 2 * $0 })
    }

    func test_rangeSubscript() {
        let list = RefList<Fixture>(order: 5)
        list.append(contentsOf: (0 ..< 30).map { Fixture($0) })

        for start in 0 ..< 30 {
            for end in start ..< 30 {
                let slice = list[start ..< end]
                XCTAssertEqual(slice.map { $0.value }, Array(start ..< end))
            }
        }

        
    }

    func test_leaks() {
        weak var list: RefList<Fixture>? = nil
        weak var test: Fixture? = nil
        do {
            let l = RefList<Fixture>(order: 5)
            l.append(contentsOf: (0 ..< 30).map { Fixture($0) })
            list = l
            test = l[10]
        }
        XCTAssertNil(list)
        XCTAssertNil(test)
    }

    func test_forEach() {
        let list = RefList<Fixture>(order: 5)
        list.append(contentsOf: (0 ..< 100).map { Fixture($0) })

        var i = 0
        list.forEach { e in
            XCTAssertEqual(e.value, i)
            i += 1
        }
        XCTAssertEqual(i, list.count)

        for start in 0 ..< list.count {
            for end in start ..< list.count {
                var i = start
                list.forEach(in: start ..< end) { e in
                    XCTAssertEqual(e.value, i)
                    i += 1
                }
                XCTAssertEqual(i, end)
            }
        }
    }
}
