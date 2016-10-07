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

@inline(never)
func noop<Value>(_ value: Value) {
}

func XCTAssertEqual<E: Equatable>(_ a: @autoclosure () -> [[E]], _ b: @autoclosure () -> [[E]], message: String? = nil, file: StaticString = #file, line: UInt = #line) {
    let av = a()
    let bv = b()
    if !av.elementsEqual(bv, by: ==) {
        XCTFail(message ?? "\(av) is not equal to \(bv)", file: file, line: line)
    }
}
