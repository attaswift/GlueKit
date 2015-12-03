//
//  SimpleSourcesTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-03.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

class SimpleSourcesTests: XCTestCase {
    
    func testEmptySource() {
        let source = Source<Int>.emptySource()

        var r = [Int]()
        let connection = source.connect { i in r.append(i) }

        XCTAssertEqual(r, []) // Well daaah

        connection.disconnect()
    }

    func testConstantSource() {
        let source = Source<Int>.constantSource(42)

        var r = [Int]()
        let connection = source.connect { i in r.append(i) }

        XCTAssertEqual(r, [42])

        connection.disconnect()
    }

}
