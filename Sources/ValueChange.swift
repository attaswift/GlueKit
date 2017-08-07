//
//  ValueChange.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-04.
//  Copyright © 2015–2017 Károly Lőrentey.
//

/// A simple change description that includes a snapshot of the value before and after the change.
public struct ValueChange<Value>: ChangeType {
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

    public mutating func merge(with next: ValueChange) {
        self.new = next.new
    }

    public func merged(with next: ValueChange) -> ValueChange {
        return .init(from: old, to: next.new)
    }

    public func reversed() -> ValueChange {
        return .init(from: new, to: old)
    }

    public func map<R>(_ transform: (Value) -> R) -> ValueChange<R> {
        return .init(from: transform(old), to: transform(new))
    }
}

extension ValueChange: CustomStringConvertible {
    public var description: String {
        return "\(old) -> \(new)"
    }
}

public func ==<Value: Equatable>(a: ValueChange<Value>, b: ValueChange<Value>) -> Bool {
    return a.old == b.old && a.new == b.new
}

public func !=<Value: Equatable>(a: ValueChange<Value>, b: ValueChange<Value>) -> Bool {
    return !(a == b)
}
