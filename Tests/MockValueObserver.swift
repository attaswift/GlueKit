//
//  MockValueObserver.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

class MockValueObserver<Value> {
    var expectedChanges: [ValueChange<Value>] = []
    var actualChanges: [ValueChange<Value>] = []
    var connection: Connection? = nil
    let eq: (Value, Value) -> Bool

    init<O: ObservableValueType>(_ target: O, _ eq: @escaping (Value, Value) -> Bool) where O.Value == Value, O.Change == ValueChange<Value> {
        self.eq = eq
        self.connection = target.changes.connect { [unowned self] change in self.apply(change) }
    }

    deinit {
        self.connection!.disconnect()
    }

    private func apply(_ change: ValueChange<Value>) {
        actualChanges.append(change)
    }

    func expectingNoChange<R>(file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        return try run(file: file, line: line, body)
    }

    func expecting<R>(_ change: ValueChange<Value>, file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        expectedChanges.append(change)
        return try run(file: file, line: line, body)
    }

    func expecting<R>(_ changes: [ValueChange<Value>], file: StaticString = #file, line: UInt = #line, body: () throws -> R) rethrows -> R {
        expectedChanges.append(contentsOf: changes)
        return try run(file: file, line: line, body)
    }

    private func run<R>(file: StaticString, line: UInt, _ body: () throws -> R) rethrows -> R {
        let result = try body()

        if !actualChanges.elementsEqual(expectedChanges, by: { eq($0.old, $1.old) && eq($0.new, $1.new) }) {
            XCTFail("\(actualChanges) is not equal to \(expectedChanges)", file: file, line: line)
        }

        actualChanges = []
        expectedChanges = []
        return result
    }
}

extension MockValueObserver where Value: Equatable {
    convenience init<O: ObservableValueType>(_ target: O) where O.Value == Value, O.Change == ValueChange<Value> {
        self.init(target, ==)
    }
}
