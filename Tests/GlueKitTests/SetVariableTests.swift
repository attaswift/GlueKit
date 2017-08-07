//
//  SetVariableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-10.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

private class Foo: Hashable, Comparable, CustomStringConvertible {
    var i: Int

    init(_ i: Int) { self.i = i }

    var hashValue: Int { return i.hashValue }
    static func ==(a: Foo, b: Foo) -> Bool { return a.i == b.i }
    static func <(a: Foo, b: Foo) -> Bool { return a.i < b.i }
    var description: String { return "\(i)" }
}

class SetVariableTests: XCTestCase {

    func testInitialization() {
        let s1 = SetVariable<Int>()
        XCTAssertEqual(s1.value, [])

        let s2 = SetVariable<Int>([1, 2, 3])
        XCTAssertEqual(s2.value, [1, 2, 3])

        let s3 = SetVariable<Int>(Set([1, 2, 3]))
        XCTAssertEqual(s3.value, [1, 2, 3])

        let s4 = SetVariable<Int>(1 ... 10)
        XCTAssertEqual(s4.value, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])

        let s5 = SetVariable<Int>(elements: 1, 2, 3)
        XCTAssertEqual(s5.value, [1, 2, 3])
    }

    func testUpdate() {
        let f1 = Foo(1)
        let f2 = Foo(2)
        let f3 = Foo(3)

        let set: SetVariable<Foo> = [f1, f2, f3]
        let mock = MockSetObserver<Foo>(set)

        let f2p = Foo(2)
        let a = mock.expecting(["begin", "[2]/[2]", "end"]) { set.update(with: f2p) }
        XCTAssertTrue(a === f2)
        let b = mock.expecting(["begin", "[2]/[2]", "end"]) { set.update(with: Foo(2)) }
        XCTAssertTrue(b === f2p)
        let c = mock.expecting(["begin", "[]/[4]", "end"]) { set.update(with: Foo(4)) }
        XCTAssertNil(c)
    }
}
