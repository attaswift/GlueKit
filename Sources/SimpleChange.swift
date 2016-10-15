//
//  SimpleChange.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-04.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

/// A simple change description that includes a snapshot of the value before and after the change.
public struct SimpleChange<Value>: ChangeType {
    public var old: Value
    public var new: Value

    public init(from old: Value, to new: Value) {
        self.old = old
        self.new = new
    }

    public var isEmpty: Bool {
        // There is no way to compare old and new at this level.
        return false
    }

    public func apply(on value: inout Value) {
        value = new
    }

    public func applied(on value: Value) -> Value {
        return new
    }

    public mutating func merge(with next: SimpleChange) {
        self.new = next.new
    }

    public func merged(with next: SimpleChange) -> SimpleChange {
        return .init(from: old, to: next.new)
    }

    public func reversed() -> SimpleChange {
        return .init(from: new, to: old)
    }

    public func map<R>(_ transform: (Value) -> R) -> SimpleChange<R> {
        return .init(from: transform(old), to: transform(new))
    }
}

public func ==<Value: Equatable>(a: SimpleChange<Value>, b: SimpleChange<Value>) -> Bool {
    return a.old == b.old && a.new == b.new
}

public func !=<Value: Equatable>(a: SimpleChange<Value>, b: SimpleChange<Value>) -> Bool {
    return !(a == b)
}
