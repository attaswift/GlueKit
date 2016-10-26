//
//  TestChange.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

internal struct TestChange: ChangeType, Equatable {
    typealias Value = Int

    var values: [Int]

    init(_ values: [Int]) {
        self.values = values
    }

    init(from oldValue: Int, to newValue: Int) {
        values = [oldValue, newValue]
    }

    var isEmpty: Bool {
        return values.isEmpty
    }

    func apply(on value: inout Int) {
        XCTAssertEqual(value, values.first!)
        value = values.last!
    }

    mutating func merge(with next: TestChange) {
        XCTAssertEqual(self.values.last!, next.values.first!)
        values += next.values.dropFirst()
    }

    func reversed() -> TestChange {
        return TestChange(values.reversed())
    }

    static func ==(left: TestChange, right: TestChange) -> Bool {
        return left.values == right.values
    }
}
