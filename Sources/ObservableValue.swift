//
//  Observable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public typealias ValueUpdate<Value> = Update<ValueChange<Value>>
public typealias ValueUpdateSource<Value> = Source<ValueUpdate<Value>>

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
    var futureValues: Source<Value> { get }

    /// Returns the type-lifted version of this ObservableValueType.
    var observable: Observable<Value> { get }
}

extension ObservableValueType where Change == ValueChange<Value> {
    public var customPlaygroundQuickLook: PlaygroundQuickLook {
        return PlaygroundQuickLook.text("\(value)")
    }

    /// Returns the type-lifted version of this ObservableValueType.
    public var observable: Observable<Value> {
        return Observable(self)
    }

    public var futureValues: Source<Value> { return changes.map { $0.new } }

    /// A source that, for each new sink, immediately sends it the current value, and thereafter delivers updated values,
    /// like `futureValues`. Implemented in terms of `futureValues` and `value`.
    public var values: Source<Value> {
        return Source<Value> { sink in
            // We assume connections are not concurrent with updates.
            // However, reentrant updates from a sink are fully supported -- they are serialized below.
            var pendingValues: [Value]? = [self.value]
            let c = self.futureValues.connect { value in
                if pendingValues != nil {
                    pendingValues!.append(value)
                }
                else {
                    sink.receive(value)
                }
            }
            while !(pendingValues!.isEmpty) {
                sink.receive(pendingValues!.removeFirst())
            }
            pendingValues = nil
            return c
        }
    }
}

/// The type lifted representation of an ObservableValueType that contains a single value with simple changes.
public struct Observable<Value>: ObservableValueType {
    private let box: AbstractObservableBase<Value>

    init(box: AbstractObservableBase<Value>) {
        self.box = box
    }
    
    /// Initializes an Observable from the given getter closure and source of future changes.
    /// @param getter A closure that returns the current value of the observable at the time of the call.
    /// @param futureValues A closure that returns a source that triggers whenever the observable changes.
    public init(getter: @escaping (Void) -> Value, updates: @escaping (Void) -> ValueUpdateSource<Value>) {
        self.box = ObservableClosureBox(getter: getter, updates: updates)
    }

    public init<Base: ObservableValueType>(_ base: Base) where Base.Value == Value {
        self.box = ObservableBox(base)
    }

    public var value: Value { return box.value }
    public var updates: ValueUpdateSource<Value> { return box.updates }
    public var futureValues: Source<Value> { return box.futureValues }
    public var observable: Observable<Value> { return self }
}

internal class AbstractObservableBase<Value>: ObservableValueType {
    typealias Change = ValueChange<Value>

    var value: Value { abstract() }
    var updates: ValueUpdateSource<Value> { abstract() }
    var futureValues: Source<Value> { return changes.map { $0.new } }

    final var observable: Observable<Value> {
        return Observable(box: self)
    }
}

internal class ObservableBox<Base: ObservableValueType>: AbstractObservableBase<Base.Value> {
    typealias Value = Base.Value

    private let base: Base

    init(_ base: Base) {
        self.base = base
    }
    override var value: Value { return base.value }
    override var updates: ValueUpdateSource<Value> { return base.updates }
    override var futureValues: Source<Value> { return base.futureValues }
}

private class ObservableClosureBox<Value>: AbstractObservableBase<Value> {
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
    public static func constant(_ value: Value) -> Observable<Value> {
        return Observable(getter: { value }, updates: { Source.empty() })
    }
}
