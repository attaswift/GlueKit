//
//  SimpleSourcesTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-03.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class SimpleSourcesTests: XCTestCase {
    
    func testEmptySource() {
        let source = AnySource<Int>.empty()

        let sink = MockSink<Int>()
        source.add(sink)

        sink.expectingNothing {
            // Ah, uhm, not sure what to test here, really
        }

        source.remove(sink)
    }

    func testNeverSource() {
        let source = AnySource<Int>.never()

        let sink = MockSink<Int>()
        source.add(sink)

        sink.expectingNothing {
            // Ah, uhm, not sure what to test here, really
        }

        source.remove(sink)
    }


    func testJustSource() {
        let source = AnySource<Int>.just(42)

        let sink = MockSink<Int>()

        _ = sink.expecting(42) {
            source.add(sink)
        }

        source.remove(sink)
    }

}
