//
//  Observable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015–2017 Károly Lőrentey.
//

public typealias ValueUpdate<Value> = Update<ValueChange<Value>>

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
public protocol ObservableValueType: ObservableType, CustomPlaygroundQuickLookable
where Change == ValueChange<Value> {
    /// Returns the type-erased version of this ObservableValueType.
    var anyObservableValue: AnyObservableValue<Value> { get }
}

extension ObservableValueType {
    /// Returns the type-erased version of this ObservableValueType.
    public var anyObservableValue: AnyObservableValue<Value> {
        return AnyObservableValue(self)
    }

    /// A source that delivers new values whenever this observable changes.
    public var futureValues: AnySource<Value> { return changes.map { $0.new } }

    /// A source that, for each new sink, immediately sends it the current value, and thereafter delivers updated values,
    /// like `futureValues`. Implemented in terms of `futureValues` and `value`.
    public var values: AnySource<Value> {
        return futureValues.bracketed(hello: { self.value }, goodbye: { nil })
    }
}

extension ObservableValueType {
    public var customPlaygroundQuickLook: PlaygroundQuickLook {
        return PlaygroundQuickLook.text("\(value)")
    }
}


/// The type erased representation of an ObservableValueType that contains a single value with simple changes.
public struct AnyObservableValue<Value>: ObservableValueType {
    public typealias Change = ValueChange<Value>

    private let box: _AbstractObservableValue<Value>

    init(box: _AbstractObservableValue<Value>) {
        self.box = box
    }
    
    /// Initializes an Observable from the given getter closure and source of future changes.
    /// @param getter A closure that returns the current value of the observable at the time of the call.
    /// @param futureValues A closure that returns a source that triggers whenever the observable changes.
    public init<Updates: SourceType>(getter: @escaping () -> Value, updates: Updates) where Updates.Value == Update<Change> {
        self.box = ObservableClosureBox(getter: getter, updates: updates)
    }

    public init<Base: ObservableValueType>(_ base: Base) where Base.Value == Value {
        self.box = ObservableValueBox(base)
    }

    public var value: Value {
        return box.value
    }

    public func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        box.add(sink)
    }

    @discardableResult
    public func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return box.remove(sink)
    }

    public var anyObservableValue: AnyObservableValue<Value> {
        return self
    }
}

open class _AbstractObservableValue<Value>: ObservableValueType {
    public typealias Change = ValueChange<Value>

    open var value: Value { abstract() }

    open func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> { abstract() }

    @discardableResult
    open func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> { abstract() }

    public final var anyObservableValue: AnyObservableValue<Value> {
        return AnyObservableValue(box: self)
    }
}

open class _BaseObservableValue<Value>: _AbstractObservableValue<Value>, TransactionalThing {
    public typealias Change = ValueChange<Value>
    var _signal: TransactionalSignal<ValueChange<Value>>? = nil
    var _transactionCount: Int = 0

    public final override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        signal.add(sink)
    }

    @discardableResult
    public final override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return signal.remove(sink)
    }

    open func activate() {
        // Do nothing
    }

    open func deactivate() {
        // Do nothing
    }
}

internal final class ObservableValueBox<Base: ObservableValueType>: _AbstractObservableValue<Base.Value> {
    typealias Value = Base.Value

    private let base: Base

    init(_ base: Base) {
        self.base = base
    }
    override var value: Value { return base.value }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        base.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return base.remove(sink)
    }
}

private final class ObservableClosureBox<Value, Updates: SourceType>: _AbstractObservableValue<Value>
where Updates.Value == Update<ValueChange<Value>> {
    private let _value: () -> Value
    private let _updates: Updates

    public init(getter: @escaping () -> Value, updates: Updates) {
        self._value = getter
        self._updates = updates
    }

    override var value: Value { return _value() }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        _updates.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return _updates.remove(sink)
    }
}

public extension ObservableValueType {
    /// Creates a constant observable wrapping the given value. The returned observable is not modifiable and it will not ever send updates.
    public static func constant(_ value: Value) -> AnyObservableValue<Value> {
        return ConstantObservable(value).anyObservableValue
    }
}

private final class ConstantObservable<Value>: _AbstractObservableValue<Value> {
    private let _value: Value

    init(_ value: Value) { _value = value }

    override var value: Value { return _value }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        // Do nothing
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        // Do nothing
        return sink
    }
}


