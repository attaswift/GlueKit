//
//  MockArrayObserver.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-06.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
import GlueKit

class MockArrayObserver<Element: Equatable> {
    var expectedChanges: [ArrayChange<Element>] = []
    var actualChanges: [ArrayChange<Element>] = []
    var connection: Connection? = nil

    init<O: ObservableArrayType>(_ target: O) where O.Element == Element, O.Change == ArrayChange<Element> {
        self.connection = target.changes.connect { [unowned self] change in self.apply(change) }
    }

    deinit {
        connection!.disconnect()
    }

    private func apply(_ change: ArrayChange<Element>) {
        actualChanges.append(change)
    }

    func expectingNoChange<R>(file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        return try run(file: file, line: line, body)
    }

    func expecting<R>(_ initialCount: Int, _ modification: ArrayModification<Element>, file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        self.expectedChanges.append(ArrayChange(initialCount: initialCount, modification: modification))
        return try run(file: file, line: line, body)
    }

    func expecting<R>(_ initialCount: Int, _ modifications: [ArrayModification<Element>], file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        var change = ArrayChange<Element>(initialCount: initialCount)
        modifications.forEach { change.add($0) }
        self.expectedChanges.append(change)
        return try run(file: file, line: line, body)
    }

    private func run<R>(file: StaticString, line: UInt, _ body: () throws -> R) rethrows -> R {
        let result = try body()
        
        let actual = merged(actualChanges)
        let expected = merged(expectedChanges)
        switch (actual, expected) {
        case let (.some(actual), .some(expected)) where actual != expected:
            fallthrough
        case (.none, .some(_)), (.some(_), .none):
            XCTFail("\(dump(actual)) is not equal to \(dump(expected))", file: file, line: line)
        default:
            break // OK
        }
        actualChanges = []
        expectedChanges = []
        return result
    }

    private func merged<E>(_ changes: [ArrayChange<E>]) -> ArrayChange<E>? {
        guard var result = changes.first else { return nil }
        if changes.count > 1 {
            for c in changes.dropFirst() {
                result.merge(with: c)
            }
        }
        return result
    }

    private func dump<E>(_ change: ArrayChange<E>?) -> String {
        guard let change = change else { return "nil" }
        return "(\(change.initialCount))" + change.modifications.map { "\($0)" }.joined()
    }

}

