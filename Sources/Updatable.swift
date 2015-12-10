//
//  Updatable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// An observable thing that also includes support for updating its value.
public protocol UpdatableType: ObservableType, SinkType {
    /// The current value of this UpdatableType. You can modify the current value by setting this property.
    var value: Change.Value {
        get
        nonmutating set // Nonmutating because UpdatableType needs to be a class if it holds the value directly.
    }
}

extension UpdatableType {
    public func receive(value: Change.Value) {
        self.value = value
    }
}

extension UpdatableType where Change == SimpleChange<SinkValue> {
    /// Returns the type-lifted version of this UpdatableType.
    public var updatable: Updatable<Change.Value> {
        return Updatable(getter: { self.value }, setter: { self.value = $0 }, futureValues: { self.futureValues })
    }
}

/// The type lifted representation of an UpdatableType.
public struct Updatable<Value>: UpdatableType {
    public typealias Change = SimpleChange<Value>

    /// The getter closure for the current value of this updatable.
    public let getter: Void->Value
    /// The setter closure for updating the current value of this updatable.
    public let setter: Value->Void
    /// A closure returning a source providing the values of future updates to this updatable.
    private let _futureValues: Void->Source<Value>

    public init(getter: Void->Value, setter: Value->Void, futureValues: Void->Source<Value>) {
        self.getter = getter
        self.setter = setter
        self._futureValues = futureValues
    }

    /// The current value of the updatable. It's called an `Updatable` because this value is settable.
    public var value: Value {
        get {
            return getter()
        }
        nonmutating set {
            setter(newValue)
        }
    }

    public var futureValues: Source<Value> {
        return _futureValues()
    }

    public var futureChanges: Source<Change> {
        return futureValues.map { SimpleChange($0) }
    }

    public func receive(value: Value) {
        self.setter(value)
    }
}

extension UpdatableType {
    /// Create a two-way binding from self to a target updatable. The target is updated to the current value of self.
    /// All future updates will be synchronized between the two variables until the returned connection is disconnected.
    /// To prevent infinite cycles, you must provide an equality test that returns true if two values are to be
    /// considered equivalent.
    @warn_unused_result(message = "You probably want to keep the connection alive by retaining it")
    public func bind<Target: UpdatableType where Target.Change.Value == Change.Value>(target: Target, equalityTest: (Change.Value, Change.Value) -> Bool) -> Connection {
        let forward = self.futureValues.connect { value in
            if !equalityTest(value, target.value) {
                target.value = value
            }
        }
        let back = target.futureValues.connect { value in
            if !equalityTest(value, self.value) {
                self.value = value
            }
        }
        forward.addCallback { id in back.disconnect() }
        target.value = self.value
        return forward
    }
}

extension UpdatableType where Change.Value: Equatable {
    /// Create a two-way binding from self to a target variable. The target is updated to the current value of self.
    /// All future updates will be synchronized between the two variables until the returned connection is disconnected.
    /// To prevent infinite cycles, the variables aren't synched when a bound variable is set to a value that is equal
    /// to the value of its counterpart.
    @warn_unused_result(message = "You probably want to keep the connection alive by retaining it")
    public func bind<Target: UpdatableType where Target.Change.Value == Change.Value>(target: Target) -> Connection {
        return self.bind(target, equalityTest: ==)
    }
}
