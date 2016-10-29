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
    var anyUpdatableValue: AnyUpdatableValue<Value> { get }
}

extension UpdatableValueType where Change == ValueChange<Value> {
    /// Returns the type-erased version of this UpdatableValueType.
    public var anyUpdatableValue: AnyUpdatableValue<Value> {
        return AnyUpdatableValue(self)
    }
}

/// The type erased representation of an UpdatableValueType.
public struct AnyUpdatableValue<Value>: UpdatableValueType {
    public typealias Change = ValueChange<Value>

    private let box: _AbstractUpdatableValue<Value>

    init(box: _AbstractUpdatableValue<Value>) {
        self.box = box
    }

    public init<Updates: SourceType>(getter: @escaping (Void) -> Value,
                                     apply: @escaping (Update<ValueChange<Value>>) -> Void,
                                     updates: Updates)
        where Updates.Value == Update<Change> {
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

    public func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        box.add(sink)
    }

    @discardableResult
    public func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return box.remove(sink)
    }

    public var anyObservableValue: AnyObservableValue<Value> {
        return box.anyObservableValue
    }

    public var anyUpdatableValue: AnyUpdatableValue<Value> {
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

    public final var anyUpdatableValue: AnyUpdatableValue<Value> { return AnyUpdatableValue(box: self) }
}

public class _BaseUpdatableValue<Value>: _AbstractUpdatableValue<Value>, SignalDelegate {
    private var state = TransactionState<ValueChange<Value>>()

    func rawGetValue() -> Value { abstract() }
    func rawSetValue(_ value: Value) { abstract() }

    public final override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        state.add(sink, with: self)
    }

    @discardableResult
    public final override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return state.remove(sink)
    }

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

internal final class UpdatableBox<Base: UpdatableValueType>: _AbstractUpdatableValue<Base.Value> where Base.Change == ValueChange<Base.Value> {
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

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        base.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return base.remove(sink)
    }
}

private final class UpdatableClosureBox<Value, Updates: SourceType>: _AbstractUpdatableValue<Value>
where Updates.Value == Update<ValueChange<Value>> {
    /// The getter closure for the current value of this updatable.
    private let _getter: () -> Value
    private let _apply: (Update<ValueChange<Value>>) -> Void
    /// A closure returning a source providing the values of future updates to this updatable.
    private let _updates: Updates

    public init(getter: @escaping () -> Value,
                apply: @escaping (Update<ValueChange<Value>>) -> Void,
                updates: Updates) {
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

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        _updates.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return _updates.remove(sink)
    }
}
