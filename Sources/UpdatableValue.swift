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
    func get() -> Value
    func update(_ body: (Value) -> Value)

    /// Returns the type-lifted version of this UpdatableValueType.
    var updatable: Updatable<Value> { get }
}

extension UpdatableValueType {
    /// The current value of this UpdatableValueType. 
    /// You can modify the current value by setting this property.
    public var value: Value {
        get { return get() }
        nonmutating set { update { _ in newValue } }
    }

    /// Returns the type-lifted version of this UpdatableValueType.
    public var updatable: Updatable<Value> {
        return Updatable(self)
    }
}

/// The type lifted representation of an UpdatableValueType.
public struct Updatable<Value>: UpdatableValueType {
    public typealias SinkValue = Value
    public typealias Change = SimpleChange<Value>

    private let box: AbstractUpdatableBase<Value>

    init(box: AbstractUpdatableBase<Value>) {
        self.box = box
    }

    public init(getter: @escaping (Void) -> Value,
                updater: @escaping ((Value) -> Value) -> Void,
                changeEvents: @escaping (Void) -> Source<ChangeEvent<Change>>) {
        self.box = UpdatableClosureBox(getter: getter, updater: updater, changeEvents: changeEvents)
    }

    public init<Base: UpdatableValueType>(_ base: Base) where Base.Value == Value {
        self.box = UpdatableBox(base)
    }

    public var value: Value {
        get { return box.value }
        set { box.value = newValue }
    }

    public func get() -> Value {
        return box.get()
    }

    public func update(_ body: (Value) -> Value) {
        box.update(body)
    }

    public func receive(_ value: Value) {
        box.receive(value)
    }

    public var changeEvents: Source<ChangeEvent<Change>> {
        return box.changeEvents
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

internal class AbstractUpdatableBase<Value>: AbstractObservableBase<Value>, UpdatableValueType {
    typealias Change = SimpleChange<Value>

    override var value: Value {
        get { return get() }
        set { update { _ in newValue } }
    }
    func receive(_ value: Value) { abstract() }
    func get() -> Value { abstract() }
    func update(_ body: (Value) -> Value) { abstract() }
    final var updatable: Updatable<Value> { return Updatable(box: self) }
}

internal class UpdatableBox<Base: UpdatableValueType>: AbstractUpdatableBase<Base.Value> {
    private let base: Base

    init(_ base: Base) {
        self.base = base
    }

    override func get() -> Base.Value { return base.get() }
    override func update(_ body: (Base.Value) -> Base.Value) { return base.update(body) }
    override var changeEvents: Source<ChangeEvent<Change>> { return base.changeEvents }
    override var futureValues: Source<Base.Value> { return base.futureValues }
}

private class UpdatableClosureBox<Value>: AbstractUpdatableBase<Value> {
    /// The getter closure for the current value of this updatable.
    private let _getter: (Void) -> Value
    /// The setter closure for updating the current value of this updatable.
    private let _updater: ((Value) -> Value) -> Void
    /// A closure returning a source providing the values of future updates to this updatable.
    private let _changeEvents: (Void) -> Source<ChangeEvent<Change>>

    public init(getter: @escaping (Void) -> Value,
                updater: @escaping ((Value) -> Value) -> Void,
                changeEvents: @escaping (Void) -> Source<ChangeEvent<Change>>) {
        self._getter = getter
        self._updater = updater
        self._changeEvents = changeEvents
    }

    override func receive(_ value: Value) {
        _updater { _ in value }
    }

    override var changeEvents: Source<ChangeEvent<Change>> {
        return _changeEvents()
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
