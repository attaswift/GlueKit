//
//  TestUtilities.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-03.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import Foundation
import GlueKit

func noop<Value>(_ value: Value) {
}

// This basic overload is missing from XCTest, so it upgrades everything to Optional which makes reports harder to read.
func XCTAssertEqual<T : Equatable>(_ expression1: @autoclosure () -> T, _ expression2: @autoclosure () -> T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    let a = expression1()
    let b = expression2()
    if a != b {
        let m = message.isEmpty ? "XCTAssertEqual failed: (\"\(a)\") is not equal to (\"\(b)\")" : message
        XCTFail(m, file: file, line: line)
    }
}


func XCTAssertEqual<E: Equatable, A: ObservableArrayType, B: Sequence where A.Iterator.Element == E, B.Iterator.Element == E>(_ a: @autoclosure () -> A, _ b: @autoclosure () -> B, message: String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(Array(a()), Array(b()), message, file: file, line: line)
}

func XCTAssertEqual<E: Equatable, A: Sequence, B: ObservableArrayType where A.Iterator.Element == E, B.Iterator.Element == E>(_ a: @autoclosure () -> A, _ b: @autoclosure () -> B, message: String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(Array(a()), Array(b()), message, file: file, line: line)
}
