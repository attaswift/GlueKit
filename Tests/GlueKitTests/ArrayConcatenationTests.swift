//
//  ArrayConcatenationTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-10.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class ArrayConcatenationTests: XCTestCase {
    func testConcatenation() {
        func check<O: ObservableArrayType>(a: [Int], b: [Int], c: O, file: StaticString = #file, line: UInt = #line) where O.Element == Int {
            XCTAssertEqual(c.count, a.count + b.count, file: file, line: line)
            let v = a + b
            XCTAssertEqual(c.value, v, file: file, line: line)
            for i in 0 ..< v.count {
                XCTAssertEqual(c[i], v[i], file: file, line: line)
                for j in i ..< v.count {
                    XCTAssertEqual(c[i ..< j], v[i ..< j], file: file, line: line)
                }
            }
        }

        let a: ArrayVariable<Int> = [0, 1, 2]
        let b: ArrayVariable<Int> = [10, 20]

        let c = a + b

        XCTAssertFalse(c.isBuffered)
        XCTAssertEqual(c.count, 5)
        XCTAssertEqual(c.value, [0, 1, 2, 10, 20])
        XCTAssertEqual(c[0], 0)
        XCTAssertEqual(c[1], 1)
        XCTAssertEqual(c[2], 2)
        XCTAssertEqual(c[3], 10)
        XCTAssertEqual(c[4], 20)
        check(a: a.value, b: b.value, c: c)

        let mock = MockArrayObserver(c)

        mock.expecting(["begin", "5.insert(30, at: 5)", "end"]) {
            b.append(30)
        }
        check(a: a.value, b: b.value, c: c)

        mock.expecting(["begin", "6.insert(3, at: 3)", "end"]) {
            a.append(3)
        }
        check(a: a.value, b: b.value, c: c)

    }
}
