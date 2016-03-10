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

func noop<Value>(value: Value) {
}

// This basic overload is missing from XCTest, so it upgrades everything to Optional which makes reports harder to read.
func XCTAssertEqual<T : Equatable>(@autoclosure expression1: () -> T, @autoclosure _ expression2: () -> T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    let a = expression1()
    let b = expression2()
    if a != b {
        let m = message.isEmpty ? "XCTAssertEqual failed: (\"\(a)\") is not equal to (\"\(b)\")" : message
        XCTFail(m, file: file, line: line)
    }
}


func XCTAssertEqual<E: Equatable, A: ObservableArrayType, B: SequenceType where A.Generator.Element == E, B.Generator.Element == E>(@autoclosure a: ()->A, @autoclosure _ b: ()->B, message: String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(Array(a()), Array(b()), message, file: file, line: line)
}

func XCTAssertEqual<E: Equatable, A: SequenceType, B: ObservableArrayType where A.Generator.Element == E, B.Generator.Element == E>(@autoclosure a: ()->A, @autoclosure _ b: ()->B, message: String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(Array(a()), Array(b()), message, file: file, line: line)
}
