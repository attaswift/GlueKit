//
//  Observable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

public typealias ValueUpdate<Value> = Update<ValueChange<Value>>
public typealias ValueUpdateSource<Value> = AnySource<ValueUpdate<Value>>

/// An observable has a value that is readable at any time, and may change in response to certain events.
/// Interested parties can sign up to receive notifications when the observable's value changes.
///
/// In GlueKit, observables are represented by types implementing `ObservableValueType`. They provide update notifications
/// via either of two sources:
///
/// - `values` sends the initial value of the observable to each new sink, followed by the values of later updates.
/// - `futureValues` skips the initial value and just sends values on future updates.
///
/// The simplest concrete observable is `Variable<Value>`, implementing a settable variable with an individual observable value.
/// `ArrayVariable<Value>` implements an observable array of values, with efficient change notifications.
///
/// If you have one or more observables, you can use GlueKit's rich set of observable transformations and compositions
/// to build observable expressions out of them.
///
/// Types implementing `ObservableValueType` are generally not type-safe; you must serialize all accesses to them
/// (including connecting to any of their sources).
///
public protocol ObservableValueType: ObservableType, CustomPlaygroundQuickLookable {
    associatedtype Value

    /// The current value of this observable.
    var value: Value { get }

    /// A source that delivers change descriptions whenever the value of this observable changes.
    var updates: ValueUpdateSource<Value> { get }

    /// A source that delivers new values whenever this observable changes.
    var futureValues: AnySource<Value> { get }

    /// Returns the type-erased version of this ObservableValueType.
    var anyObservable: AnyObservableValue<Value> { get }
}

extension ObservableValueType where Change == ValueChange<Value> {
    /// Returns the type-erased version of this ObservableValueType.
    public var anyObservable: AnyObservableValue<Value> {
        return AnyObservableValue(self)
    }

    public var futureValues: AnySource<Value> { return changes.map { $0.new } }

    /// A source that, for each new sink, immediately sends it the current value, and thereafter delivers updated values,
    /// like `futureValues`. Implemented in terms of `futureValues` and `value`.
    public var values: AnySource<Value> {
        return futureValues.bracketed(hello: { self.value }, goodbye: { nil })
    }
}

extension ObservableValueType where Change == ValueChange<Value> {
    public var customPlaygroundQuickLook: PlaygroundQuickLook {
        return PlaygroundQuickLook.text("\(value)")
    }
}


/// The type erased representation of an ObservableValueType that contains a single value with simple changes.
public struct AnyObservableValue<Value>: ObservableValueType {
    private let box: _AbstractObservableValue<Value>

    init(box: _AbstractObservableValue<Value>) {
        self.box = box
    }
    
    /// Initializes an Observable from the given getter closure and source of future changes.
    /// @param getter A closure that returns the current value of the observable at the time of the call.
    /// @param futureValues A closure that returns a source that triggers whenever the observable changes.
    public init(getter: @escaping (Void) -> Value, updates: @escaping (Void) -> ValueUpdateSource<Value>) {
        self.box = ObservableClosureBox(getter: getter, updates: updates)
    }

    public init<Base: ObservableValueType>(_ base: Base) where Base.Value == Value, Base.Change == ValueChange<Value> {
        self.box = ObservableValueBox(base)
    }

    public var value: Value { return box.value }
    public var updates: ValueUpdateSource<Value> { return box.updates }
    public var futureValues: AnySource<Value> { return box.futureValues }
    public var anyObservable: AnyObservableValue<Value> { return self }
}

open class _AbstractObservableValue<Value>: ObservableValueType {
    public typealias Change = ValueChange<Value>

    open var value: Value { abstract() }
    open var updates: ValueUpdateSource<Value> { abstract() }

    open var futureValues: AnySource<Value> {
        return changes.map { $0.new }
    }

    public final var anyObservable: AnyObservableValue<Value> {
        return AnyObservableValue(box: self)
    }
}

open class _BaseObservableValue<Value>: _AbstractObservableValue<Value>, Signaler {
    private var state = TransactionState<ValueChange<Value>>()

    public final override var updates: ValueUpdateSource<Value> { return state.source(retaining: self) }

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

internal class ObservableValueBox<Base: ObservableValueType>: _AbstractObservableValue<Base.Value> {
    typealias Value = Base.Value

    private let base: Base

    init(_ base: Base) {
        self.base = base
    }
    override var value: Value { return base.value }
    override var updates: ValueUpdateSource<Value> { return base.updates }
    override var futureValues: AnySource<Value> { return base.futureValues }
}

private class ObservableClosureBox<Value>: _AbstractObservableValue<Value> {
    private let _value: () -> Value
    private let _updates: () -> ValueUpdateSource<Value>

    public init(getter: @escaping (Void) -> Value, updates: @escaping (Void) -> ValueUpdateSource<Value>) {
        self._value = getter
        self._updates = updates
    }

    override var value: Value { return _value() }
    override var updates: ValueUpdateSource<Value> { return _updates() }
}

public extension ObservableValueType {
    /// Creates a constant observable wrapping the given value. The returned observable is not modifiable and it will not ever send updates.
    public static func constant(_ value: Value) -> AnyObservableValue<Value> {
        return ConstantObservable(value).anyObservable
    }
}

private class ConstantObservable<Value>: _AbstractObservableValue<Value> {
    private let _value: Value

    init(_ value: Value) { _value = value }

    override var value: Value { return _value }

    override var updates: AnySource<Update<ValueChange<Value>>> {
        return .empty()
    }
}

extension Connector {
    @discardableResult
    public func connect<Source: SourceType>(_ source: Source, to sink: @escaping (Source.Value) -> Void) -> Connection {
        return source.connect(sink).putInto(self)
    }

    @discardableResult
    public func connect<Observable: ObservableType>(_ observable: Observable, to sink: @escaping (Observable.Change) -> Void) -> Connection {
        return observable.changes.connect(sink).putInto(self)
    }
}

