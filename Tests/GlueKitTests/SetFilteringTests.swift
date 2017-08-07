//
//  SetFilteringTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-06.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit

class SetFilteringTests: XCTestCase {

    func test_filter_simplePredicate() {
        let set = SetVariable<Int>(0 ..< 10)
        let even = set.filter { $0 & 1 == 0 }

        XCTAssertFalse(even.isBuffered)
        XCTAssertEqual(even.count, 5)
        XCTAssertEqual(even.value, [0, 2, 4, 6, 8])
        XCTAssertTrue(even.contains(0))
        XCTAssertFalse(even.contains(1))

        XCTAssertTrue(even.isSubset(of: Set(0 ..< 10)))
        XCTAssertTrue(even.isSubset(of: Set(-1 ..< 11)))
        XCTAssertFalse(even.isSubset(of: Set(1 ..< 20)))

        XCTAssertTrue(even.isSuperset(of: []))
        XCTAssertTrue(even.isSuperset(of: [2, 4, 6]))
        XCTAssertTrue(even.isSuperset(of: [0, 2, 4, 6, 8]))
        XCTAssertFalse(even.isSuperset(of: [2, 5, 6]))

        let mock = MockSetObserver(even)

        // Repeat basic tests with an active connection.
        XCTAssertFalse(even.isBuffered)
        XCTAssertEqual(even.count, 5)
        XCTAssertEqual(even.value, [0, 2, 4, 6, 8])
        XCTAssertTrue(even.contains(0))
        XCTAssertFalse(even.contains(1))

        XCTAssertTrue(even.isSubset(of: Set(0 ..< 10)))
        XCTAssertTrue(even.isSubset(of: Set(-1 ..< 11)))
        XCTAssertFalse(even.isSubset(of: Set(1 ..< 20)))

        XCTAssertTrue(even.isSuperset(of: []))
        XCTAssertTrue(even.isSuperset(of: [2, 4, 6]))
        XCTAssertTrue(even.isSuperset(of: [0, 2, 4, 6, 8]))
        XCTAssertFalse(even.isSuperset(of: [2, 5, 6]))

        // Now try some modifications

        mock.expecting(["begin", "[]/[10]", "end"]) { set.insert(10) }
        XCTAssertEqual(even.value, [0, 2, 4, 6, 8, 10])

        mock.expecting(["begin", "end"]) { set.insert(11) }
        XCTAssertEqual(even.value, [0, 2, 4, 6, 8, 10])

        mock.expecting(["begin", "end"]) { set.remove(5) }
        XCTAssertEqual(even.value, [0, 2, 4, 6, 8, 10])

        mock.expecting(["begin", "[6]/[]", "end"]) { set.remove(6) }
        XCTAssertEqual(even.value, [0, 2, 4, 8, 10])
    }

    func test_filter_observableBool() {
        var f = (0 ..< 15).map { Foo($0) }
        let set = SetVariable<Foo>(f[0 ..< 10])
        let even = set.filter { $0.isEven }

        XCTAssertFalse(even.isBuffered)
        XCTAssertEqual(even.count, 5)
        XCTAssertEqual(even.value, [f[0], f[2], f[4], f[6], f[8]])
        XCTAssertTrue(even.contains(f[0]))
        XCTAssertFalse(even.contains(f[1]))

        XCTAssertTrue(even.isSubset(of: Set(f)))
        XCTAssertTrue(even.isSubset(of: Set(f + [Foo(10), Foo(-1)])))
        XCTAssertFalse(even.isSubset(of: [f[0], f[2], f[5], f[6], f[8]]))

        XCTAssertTrue(even.isSuperset(of: []))
        XCTAssertTrue(even.isSuperset(of: [f[2], f[4], f[6]]))
        XCTAssertTrue(even.isSuperset(of: [f[0], f[2], f[4], f[6], f[8]]))
        XCTAssertFalse(even.isSuperset(of: [f[2], f[5], f[6]]))

        let mock = MockSetObserver<Foo>(even)

        // Repeat basic tests with an active connection.
        XCTAssertFalse(even.isBuffered)
        XCTAssertEqual(even.count, 5)
        XCTAssertEqual(even.value, [f[0], f[2], f[4], f[6], f[8]])
        XCTAssertTrue(even.contains(f[0]))
        XCTAssertFalse(even.contains(f[1]))

        XCTAssertTrue(even.isSubset(of: Set(f)))
        XCTAssertTrue(even.isSubset(of: Set(f + [Foo(10), Foo(-1)])))
        XCTAssertFalse(even.isSubset(of: [f[0], f[2], f[5], f[6], f[8]]))

        XCTAssertTrue(even.isSuperset(of: []))
        XCTAssertTrue(even.isSuperset(of: [f[2], f[4], f[6]]))
        XCTAssertTrue(even.isSuperset(of: [f[0], f[2], f[4], f[6], f[8]]))
        XCTAssertFalse(even.isSuperset(of: [f[2], f[5], f[6]]))

        // Now try some modifications
        mock.expecting(["begin", "[]/[10]", "end"]) {
            set.insert(f[10])
        }
        XCTAssertEqual(even.value, [f[0], f[2], f[4], f[6], f[8], f[10]])
        mock.expecting(["begin", "end"]) {
            set.insert(f[11])
        }
        XCTAssertEqual(even.value, [f[0], f[2], f[4], f[6], f[8], f[10]])
        mock.expecting(["begin", "end"]) {
            set.remove(f[3])
        }
        XCTAssertEqual(even.value, [f[0], f[2], f[4], f[6], f[8], f[10]])
        mock.expecting(["begin", "[4]/[]", "end"]) {
            set.remove(f[4])
        }
        XCTAssertEqual(even.value, [f[0], f[2], f[6], f[8], f[10]])
        mock.expecting(["begin", "[]/[11]", "end"]) {
            f[11].number.value = 10
        }
        XCTAssertEqual(even.value, [f[0], f[2], f[6], f[8], f[10], f[11]])
        mock.expecting(["begin", "[8]/[]", "end"]) {
            f[8].number.value = 9
        }
        XCTAssertEqual(even.value, [f[0], f[2], f[6], f[10], f[11]])
        mock.expecting(["begin", "end"]) {
            f[8].number.value = 7
        }
        XCTAssertEqual(even.value, [f[0], f[2], f[6], f[10], f[11]])
        mock.expecting(["begin", "end"]) {
            f[6].number.value = 8
        }
        XCTAssertEqual(even.value, [f[0], f[2], f[6], f[10], f[11]])
    }

    func test_filter_observablePredicate() {
        let predicate = Variable<(Int) -> Bool> { $0 & 1 == 0 }
        let set = SetVariable<Int>(0 ..< 10)

        let filtered = set.filter(predicate)

        XCTAssertEqual(filtered.value, [0, 2, 4, 6, 8])

        let mock = MockSetObserver(filtered)

        mock.expecting(["begin", "[]/[10]", "end"]) { set.insert(10) }
        mock.expecting(["begin", "[6, 8, 10]/[1, 3, 5]", "end"]) { predicate.value = { $0 <= 5 } }
        mock.expecting(["begin", "[]/[-1]", "end"]) { set.insert(-1) }
        mock.expecting(["begin", "[0, 2, 4]/[7, 9]", "end"]) { predicate.value = { $0 & 1 == 1 } }
    }

    func test_filter_observableOptionalPredicate() {
        let predicate = Variable<Optional<(Int) -> Bool>> { $0 & 1 == 0 }
        let set = SetVariable<Int>(0 ..< 10)

        let filtered = set.filter(predicate)

        XCTAssertEqual(filtered.value, [0, 2, 4, 6, 8])

        let mock = MockSetObserver(filtered)

        mock.expecting(["begin", "[]/[10]", "end"]) { set.insert(10) }
        mock.expecting(["begin", "[6, 8, 10]/[1, 3, 5]", "end"]) { predicate.value = { $0 <= 5 } }
        mock.expecting(["begin", "[]/[-1]", "end"]) { set.insert(-1) }
        mock.expecting(["begin", "[0, 2, 4]/[7, 9]", "end"]) { predicate.value = { $0 & 1 == 1 } }
        mock.expecting(["begin", "[]/[0, 2, 4, 6, 8, 10]", "end"]) { predicate.value = nil }
    }
}

private final class Foo: Hashable, Comparable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    let id: Int
    let number: IntVariable

    var isEven: AnyObservableValue<Bool> { return number.map { $0 & 1 == 0 } }

    init(_ number: Int) {
        self.id = number
        self.number = .init(number)
    }
    convenience init(integerLiteral value: Int) { self.init(value) }
    var hashValue: Int { return ObjectIdentifier(self).hashValue }
    var description: String { return "\(id)" }
    static func == (a: Foo, b: Foo) -> Bool { return a === b }
    static func < (a: Foo, b: Foo) -> Bool { return a.number.value < b.number.value }
}
