//
//  MockSetObserver.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-06.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
import GlueKit

class MockSetObserver<Element: Hashable & Comparable> {
    private var actualChanges: [String] = []
    private var expectedChanges: [String] = []
    private var connection: Connection? = nil

    init<Target: ObservableSetType>(_ target: Target) where Target.Element == Element {
        self.connection = target.changes.connect { [unowned self] change in
            self.apply(change)
        }
    }

    deinit {
        connection!.disconnect()
    }

    func expectingNoChange<R>(file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        return try run(file: file, line: line, body: body)
    }

    func expecting<R>(_ change: String, file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        expectedChanges.append(change)
        return try run(file: file, line: line, body: body)
    }

    func expecting<R>(_ changes: [String], file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        expectedChanges.append(contentsOf: changes)
        return try run(file: file, line: line, body: body)
    }

    private func run<R>(file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        defer {
            expectedChanges.removeAll()
            actualChanges.removeAll()
        }
        let result = try body()
        XCTAssertEqual(actualChanges, expectedChanges, file: file, line: line)
        return result
    }

    private func apply(_ change: SetChange<Element>) {
        let removed = change.removed.sorted().map { "\($0)" }.joined(separator: ", ")
        let inserted = change.inserted.sorted().map { "\($0)" }.joined(separator: ", ")
        actualChanges.append("[\(removed)]/[\(inserted)]")
    }
}
