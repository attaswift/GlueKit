//
//  SetFoldingTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class SetFoldingTests: XCTestCase {

    func testSum() {
        let set = SetVariable<Int>([1, 2, 3])
        let sum = set.sum()

        XCTAssertEqual(sum.value, 6)

        set.insert(4)
        XCTAssertEqual(sum.value, 10)

        set.formUnion([5, 6])
        XCTAssertEqual(sum.value, 21)

        set.remove(1)
        XCTAssertEqual(sum.value, 20)

        set.subtract([2, 4])
        XCTAssertEqual(sum.value, 14)
        
        set.removeAll()
        XCTAssertEqual(sum.value, 0)
    }

}
