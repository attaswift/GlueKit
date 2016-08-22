//
//  Observable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// An observable has a value that is readable at any time, and may change in response to certain events.
/// Interested parties can sign up to receive notifications when the observable's value changes.
///
/// In GlueKit, observables are represented by types implementing `ObservableType`. They provide update notifications
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
/// Types implementing `ObservableType` are generally not type-safe; you must serialize all accesses to them
/// (including connecting to any of their sources).
///
public protocol ObservableType {
    associatedtype Value

    /// The current value of this observable.
    var value: Value { get }

    /// A source that delivers new values whenever this observable changes.
    var futureValues: Source<Value> { get }

    /// Returns the type-lifted version of this ObservableType.
    var observable: Observable<Value> { get }
}

extension ObservableType {

    /// Returns the type-lifted version of this ObservableType.
    public var observable: Observable<Value> {
        return Observable(self)
    }
}

extension ObservableType {
    /// A source that, for each new sink, immediately sends it the current value, and thereafter delivers updated values,
    /// like `futureValues`. Implemented in terms of `futureValues` and `value`.
    public var values: Source<Value> {
        return Source<Value> { sink in
            // We assume connections not concurrent with updates.
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

/// The type lifted representation of an ObservableType that contains a single value with simple changes.
public struct Observable<Value>: ObservableType {
    private let box: ObservableBoxBase<Value>

    init(box: ObservableBoxBase<Value>) {
        self.box = box
    }
    
    /// Initializes an Observable from the given getter closure and source of future changes.
    /// @param getter A closure that returns the current value of the observable at the time of the call.
    /// @param futureValues A closure that returns a source that triggers whenever the observable changes.
    public init(getter: @escaping (Void) -> Value, futureValues: @escaping (Void) -> Source<Value>) {
        self.box = ObservableClosureBox(getter: getter, futureValues: futureValues)
    }

    public init<Base: ObservableType>(_ base: Base) where Base.Value == Value {
        self.box = ObservableBox(base)
    }

    public var value: Value { return box.value }
    public var futureValues: Source<Value> { return box.futureValues }
}

internal class ObservableBoxBase<Value>: ObservableType {
    var value: Value { abstract() }
    var futureValues: Source<Value> { abstract() }

    final var observable: Observable<Value> {
        return Observable(box: self)
    }
}

internal class ObservableBox<Base: ObservableType>: ObservableBoxBase<Base.Value> {
    private let base: Base

    init(_ base: Base) {
        self.base = base
    }
    override var value: Base.Value { return base.value }
    override var futureValues: Source<Base.Value> { return base.futureValues }
}

private class ObservableClosureBox<Value>: ObservableBoxBase<Value> {
    private let _value: () -> Value
    private let _futureValues: () -> Source<Value>

    public init(getter: @escaping (Void) -> Value, futureValues: @escaping (Void) -> Source<Value>) {
        self._value = getter
        self._futureValues = futureValues
    }

    override var value: Value { return _value() }
    override var futureValues: Source<Value> { return _futureValues() }
}

public extension ObservableType {
    /// Creates a constant observable wrapping the given value. The returned observable is not modifiable and it will not ever send updates.
    public static func constant(_ value: Value) -> Observable<Value> {
        return Observable(getter: { value }, futureValues: { Source.empty() })
    }
}
