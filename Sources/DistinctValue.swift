//
//  DistinctValue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

public extension ObservableValueType where Change == ValueChange<Value> {
    public func distinct(_ areEquivalent: @escaping (Value, Value) -> Bool) -> AnyObservableValue<Value> {
        return DistinctObservableValue(self, by: areEquivalent).anyObservable
    }
}

public extension ObservableValueType where Change == ValueChange<Value>, Value: Equatable {
    public func distinct() -> AnyObservableValue<Value> {
        return distinct(==)
    }
}

private class DistinctObservableValue<Input: ObservableValueType>: _AbstractObservableValue<Input.Value> where Input.Change == ValueChange<Input.Value> {
    typealias Value = Input.Value

    private let input: Input
    private let areEquivalent: (Value, Value) -> Bool

    init(_ input: Input, by areEquivalent: @escaping (Value, Value) -> Bool) {
        self.input = input
        self.areEquivalent = areEquivalent
    }

    override var value: Value {
        return input.value
    }

    override var updates: ValueUpdateSource<Value> {
        return input.updates.flatMap { update in update.filter { !self.areEquivalent($0.old, $0.new) } }
    }
}

public extension UpdatableValueType where Change == ValueChange<Value> {
    public func distinct(_ areEquivalent: @escaping (Value, Value) -> Bool) -> AnyUpdatableValue<Value> {
        return DistinctUpdatableValue(self, by: areEquivalent).anyUpdatable
    }
}

public extension UpdatableValueType where Change == ValueChange<Value>, Value: Equatable {
    public func distinct() -> AnyUpdatableValue<Value> {
        return distinct(==)
    }
}

private class DistinctUpdatableValue<Input: UpdatableValueType>: _AbstractUpdatableValue<Input.Value> where Input.Change == ValueChange<Input.Value> {
    typealias Value = Input.Value

    private let input: Input
    private let areEquivalent: (Value, Value) -> Bool

    init(_ input: Input, by areEquivalent: @escaping (Value, Value) -> Bool) {
        self.input = input
        self.areEquivalent = areEquivalent
    }

    override var value: Value {
        get {
            return input.value
        }
        set {
            input.value = newValue
        }
    }

    override func withTransaction<Result>(_ body: () -> Result) -> Result {
        return input.withTransaction(body)
    }


    override var updates: ValueUpdateSource<Value> {
        return input.updates.flatMap { update in update.filter { !self.areEquivalent($0.old, $0.new) } }
    }
}
