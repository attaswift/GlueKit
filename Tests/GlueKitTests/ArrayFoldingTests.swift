//
//  ArrayFoldingTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class ArrayFoldingTests: XCTestCase {
    
    func testSum() {
        let array = ArrayVariable<Int>([1, 2, 3])
        let sum = array.sum()

        XCTAssertEqual(sum.value, 6)

        array.append(4)
        XCTAssertEqual(sum.value, 10)

        array.insert(5, at: 1)
        XCTAssertEqual(sum.value, 15)

        array.remove(at: 0)
        XCTAssertEqual(sum.value, 14)

        array.removeAll()
        XCTAssertEqual(sum.value, 0)
    }        
}
