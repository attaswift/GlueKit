//
//  Updatable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// An observable thing that also includes support for updating its value.
public protocol UpdatableValueType: ObservableValueType, UpdatableType {
    /// The current value of this UpdatableValueType. You can modify the current value by setting this property.
    var value: Value {
        get
        nonmutating set // Nonmutating because UpdatableValueType needs to be a class if it holds the value directly.
    }

    /// Returns the type-lifted version of this UpdatableValueType.
    var updatable: Updatable<Value> { get }
}

extension UpdatableValueType {
    /// Returns the type-lifted version of this UpdatableValueType.
    public var updatable: Updatable<Value> {
        return Updatable(self)
    }
}

/// The type lifted representation of an UpdatableValueType.
public struct Updatable<Value>: UpdatableValueType {
    public typealias SinkValue = Value

    private let box: UpdatableBoxBase<Value>

    init(box: UpdatableBoxBase<Value>) {
        self.box = box
    }

    public init(getter: @escaping (Void) -> Value, setter: @escaping (Value) -> Void, changes: @escaping (Void) -> Source<SimpleChange<Value>>) {
        self.box = UpdatableClosureBox(getter: getter, setter: setter, changes: changes)
    }

    public init<Base: UpdatableValueType>(_ base: Base) where Base.Value == Value {
        self.box = UpdatableBox(base)
    }

    /// The current value of the updatable. It's called an `Updatable` because this value is settable.
    public var value: Value {
        get {
            return box.value
        }
        nonmutating set {
            box.value = newValue
        }
    }

    public func receive(_ value: Value) {
        box.receive(value)
    }

    public var changes: Source<SimpleChange<Value>> {
        return box.changes
    }

    public var futureValues: Source<Value> {
        return box.futureValues
    }

    public var observable: Observable<Value> {
        return box.observable
    }

    public var updatable: Updatable<Value> {
        return self
    }
}

internal class UpdatableBoxBase<Value>: ObservableBoxBase<Value>, UpdatableValueType {
    override var value: Value {
        get { abstract() }
        set { abstract() }
    }
    func receive(_ value: Value) { abstract() }
    final var updatable: Updatable<Value> { return Updatable(box: self) }
}

internal class UpdatableBox<Base: UpdatableValueType>: UpdatableBoxBase<Base.Value> {
    private let base: Base

    init(_ base: Base) {
        self.base = base
    }

    override var value: Base.Value {
        get { return base.value }
        set { base.value = newValue }
    }
    override var changes: Source<SimpleChange<Base.Value>> { return base.changes }
    override var futureValues: Source<Base.Value> { return base.futureValues }
}

private class UpdatableClosureBox<Value>: UpdatableBoxBase<Value> {
    /// The getter closure for the current value of this updatable.
    let getter: (Void) -> Value
    /// The setter closure for updating the current value of this updatable.
    let setter: (Value) -> Void
    /// A closure returning a source providing the values of future updates to this updatable.
    let changeSource: (Void) -> Source<SimpleChange<Value>>

    public init(getter: @escaping (Void) -> Value, setter: @escaping (Value) -> Void, changes: @escaping (Void) -> Source<SimpleChange<Value>>) {
        self.getter = getter
        self.setter = setter
        self.changeSource = changes
    }

    override var value: Value {
        get { return getter() }
        set { setter(newValue) }
    }

    override func receive(_ value: Value) {
        setter(value)
    }

    override var changes: Source<SimpleChange<Value>> {
        return changeSource()
    }
}

extension UpdatableValueType {
    /// Create a two-way binding from self to a target updatable. The target is updated to the current value of self.
    /// All future updates will be synchronized between the two variables until the returned connection is disconnected.
    /// To prevent infinite cycles, you must provide an equality test that returns true if two values are to be
    /// considered equivalent.
    public func bind<Target: UpdatableValueType>(_ target: Target, equalityTest: @escaping (Value, Value) -> Bool) -> Connection where Target.Value == Value {
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

extension UpdatableValueType where Value: Equatable {
    /// Create a two-way binding from self to a target variable. The target is updated to the current value of self.
    /// All future updates will be synchronized between the two variables until the returned connection is disconnected.
    /// To prevent infinite cycles, the variables aren't synched when a bound variable is set to a value that is equal
    /// to the value of its counterpart.
    public func bind<Target: UpdatableValueType>(_ target: Target) -> Connection where Target.Value == Value {
        return self.bind(target, equalityTest: ==)
    }
}
