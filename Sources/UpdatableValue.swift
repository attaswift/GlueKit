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
                apply: @escaping (Update<ValueChange<Value>>) -> Void,
                updates: @escaping (Void) -> ValueUpdateSource<Value>) {
        self.box = UpdatableClosureBox(getter: getter,
                                       apply: apply,
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

    public func apply(_ update: Update<Change>) {
        box.apply(update)
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
    open func apply(_ update: Update<Change>) { abstract() }

    public final var anyUpdatable: AnyUpdatableValue<Value> { return AnyUpdatableValue(box: self) }
}

public class _BaseUpdatableValue<Value>: _AbstractUpdatableValue<Value>, SignalDelegate {
    private var state = TransactionState<ValueChange<Value>>()

    func rawGetValue() -> Value { abstract() }
    func rawSetValue(_ value: Value) { abstract() }

    public final override var updates: ValueUpdateSource<Value> { return state.source(delegate: self) }

    public final override var value: Value {
        get {
            return rawGetValue()
        }
        set {
            beginTransaction()
            let old = rawGetValue()
            rawSetValue(newValue)
            sendChange(ValueChange(from: old, to: newValue))
            endTransaction()
        }
    }

    public final override func apply(_ update: Update<Change>) {
        switch update {
        case .beginTransaction:
            state.begin()
        case .change(let change):
            rawSetValue(change.new)
            sendChange(change)
        case .endTransaction:
            state.end()
        }
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

    final func send(_ update: Update<Change>) {
        state.send(update)
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

    override func apply(_ update: Update<ValueChange<Value>>) {
        base.apply(update)
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
    private let _getter: () -> Value
    private let _apply: (Update<ValueChange<Value>>) -> Void
    /// A closure returning a source providing the values of future updates to this updatable.
    private let _updates: (Void) -> ValueUpdateSource<Value>

    public init(getter: @escaping () -> Value,
                apply: @escaping (Update<ValueChange<Value>>) -> Void,
                updates: @escaping (Void) -> ValueUpdateSource<Value>) {
        self._getter = getter
        self._apply = apply
        self._updates = updates
    }

    override var value: Value {
        get { return _getter() }
        set {
            _apply(.beginTransaction)
            _apply(.change(ValueChange(from: _getter(), to: newValue)))
            _apply(.endTransaction)
        }
    }

    override func apply(_ update: Update<ValueChange<Value>>) {
        _apply(update)
    }

    override var updates: ValueUpdateSource<Value> {
        return _updates()
    }
}
