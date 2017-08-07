//
//  BracketingSourceTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class BracketingSourceTests: XCTestCase {
    func testHello() {
        let source = Signal<Int>()

        var helloCount = 0
        let bracket = source.bracketed(hello: { helloCount += 1; return 0 },
                                       goodbye: { return nil })


        XCTAssertFalse(source.isConnected)

        let s1 = MockSink<Int>()

        s1.expecting(0) {
            bracket.add(s1)
        }
        XCTAssertTrue(source.isConnected)
        XCTAssertEqual(helloCount, 1)

        s1.expecting(1) {
            source.send(1)
        }

        let s2 = MockSink<Int>()
        s2.expecting(0) {
            bracket.add(s2)
        }
        XCTAssertEqual(helloCount, 2)

        s1.expecting(2) {
            s2.expecting(2) {
                source.send(2)
            }
        }

        s1.expectingNothing {
            _ = bracket.remove(s1)
        }

        s2.expecting(3) {
            source.send(3)
        }

        s2.expectingNothing {
            _ = bracket.remove(s2)
        }

        XCTAssertFalse(source.isConnected)
        XCTAssertEqual(helloCount, 2)
    }

    func testGoodbye() {
        let source = Signal<Int>()

        var goodbyeCount = 0
        let bracket = source.bracketed(hello: { return nil },
                                       goodbye: { goodbyeCount += 1; return 0 })


        XCTAssertFalse(source.isConnected)

        let s1 = MockSink<Int>()

        s1.expectingNothing {
            bracket.add(s1)
        }
        XCTAssertTrue(source.isConnected)
        XCTAssertEqual(goodbyeCount, 0)

        s1.expecting(1) {
            source.send(1)
        }

        let s2 = MockSink<Int>()
        s2.expectingNothing {
            bracket.add(s2)
        }
        XCTAssertEqual(goodbyeCount, 0)

        s1.expecting(2) {
            s2.expecting(2) {
                source.send(2)
            }
        }

        s1.expecting(0) {
            _ = bracket.remove(s1)
        }
        XCTAssertEqual(goodbyeCount, 1)

        s2.expecting(3) {
            source.send(3)
        }

        s2.expecting(0) {
            _ = bracket.remove(s2)
        }        
        XCTAssertFalse(source.isConnected)
        XCTAssertEqual(goodbyeCount, 2)
    }

}
