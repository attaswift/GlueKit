//
//  Updatable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

/// An observable thing that also includes support for updating its value.
public protocol UpdatableValueType: ObservableValueType, UpdatableType {
    /// Returns the type-erased version of this UpdatableValueType.
    var anyUpdatable: AnyUpdatableValue<Value> { get }
}

extension UpdatableValueType where Change == ValueChange<Value> {
    /// Returns the type-erased version of this UpdatableValueType.
    public var anyUpdatable: AnyUpdatableValue<Value> {
        return AnyUpdatableValue(self)
    }
}

/// The type erased representation of an UpdatableValueType.
public struct AnyUpdatableValue<Value>: UpdatableValueType {
    public typealias SinkValue = Value
    public typealias Change = ValueChange<Value>

    private let box: _AbstractUpdatableValue<Value>

    init(box: _AbstractUpdatableValue<Value>) {
        self.box = box
    }

    public init(getter: @escaping (Void) -> Value,
                setter: @escaping (Value) -> Void,
                transaction: @escaping (() -> Void) -> Void,
                updates: @escaping (Void) -> ValueUpdateSource<Value>) {
        self.box = UpdatableClosureBox(getter: getter,
                                       setter: setter,
                                       transaction: transaction,
                                       updates: updates)
    }

    public init<Base: UpdatableValueType>(_ base: Base)
    where Base.Value == Value, Base.Change == ValueChange<Value> {
        self.box = UpdatableBox(base)
    }

    public var value: Value {
        get { return box.value }
        nonmutating set { box.value = newValue }
    }

    public func withTransaction<Result>(_ body: () -> Result) -> Result {
        return box.withTransaction(body)
    }

    public var updates: ValueUpdateSource<Value> {
        return box.updates
    }

    public var futureValues: AnySource<Value> {
        return box.futureValues
    }

    public var anyObservable: AnyObservableValue<Value> {
        return box.anyObservable
    }

    public var anyUpdatable: AnyUpdatableValue<Value> {
        return self
    }
}

open class _AbstractUpdatableValue<Value>: _AbstractObservableValue<Value>, UpdatableValueType {
    public typealias Change = ValueChange<Value>

    open override var value: Value {
        get { abstract() }
        set { abstract() }
    }
    open func withTransaction<Result>(_ body: () -> Result) -> Result { abstract() }

    public final var anyUpdatable: AnyUpdatableValue<Value> { return AnyUpdatableValue(box: self) }
}

open class _BaseUpdatableValue<Value>: _AbstractUpdatableValue<Value>, Signaler {
    private var state = TransactionState<ValueChange<Value>>()

    public final override var updates: ValueUpdateSource<Value> { return state.source(retaining: self) }

    public final override func withTransaction<Result>(_ body: () -> Result) -> Result {
        state.begin()
        defer { state.end() }
        return body()
    }

    final func beginTransaction() {
        state.begin()
    }

    final func endTransaction() {
        state.end()
    }

    final func sendChange(_ change: Change) {
        state.send(change)
    }

    open func activate() {
        // Do nothing
    }

    open func deactivate() {
        // Do nothing
    }
}

internal class UpdatableBox<Base: UpdatableValueType>: _AbstractUpdatableValue<Base.Value> where Base.Change == ValueChange<Base.Value> {
    typealias Value = Base.Value
    private let base: Base

    init(_ base: Base) {
        self.base = base
    }

    override var value: Value {
        get { return base.value }
        set { base.value = newValue }
    }

    override func withTransaction<Result>(_ body: () -> Result) -> Result {
        return base.withTransaction(body)
    }

    override var updates: ValueUpdateSource<Value> {
        return base.updates
    }

    override var futureValues: AnySource<Value> {
        return base.futureValues
    }
}

private class UpdatableClosureBox<Value>: _AbstractUpdatableValue<Value> {
    /// The getter closure for the current value of this updatable.
    private let _getter: (Void) -> Value
    /// The setter closure for updating the current value of this updatable.
    private let _setter: (Value) -> Void
    private let _transaction: (() -> Void) -> Void
    /// A closure returning a source providing the values of future updates to this updatable.
    private let _updates: (Void) -> ValueUpdateSource<Value>

    public init(getter: @escaping (Void) -> Value,
                setter: @escaping (Value) -> Void,
                transaction: @escaping (() -> Void) -> Void,
                updates: @escaping (Void) -> ValueUpdateSource<Value>) {
        self._getter = getter
        self._setter = setter
        self._transaction = transaction
        self._updates = updates
    }

    override var value: Value {
        get { return _getter() }
        set { _setter(newValue) }
    }

    override func withTransaction<Result>(_ body: () -> Result) -> Result {
        var result: Result? = nil
        _transaction {
            result = body()
        }
        return result!
    }

    override var updates: ValueUpdateSource<Value> {
        return _updates()
    }
}
