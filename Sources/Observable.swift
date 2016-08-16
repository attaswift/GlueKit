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
}

extension ObservableType {

    /// Returns the type-lifted version of this ObservableType.
    public var observable: Observable<Value> {
        return Observable<Value>(getter: { self.value }, futureValues: { self.futureValues })
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
    /// The getter closure for the current value of this observable.
    fileprivate let getter: (Void) -> Value

    /// A closure providing a source providing the values of future updates to this observable.
    fileprivate let valueSource: (Void) -> Source<Value>

    /// Initializes an Observable from the given getter closure and source of future changes.
    /// @param getter A closure that returns the current value of the observable at the time of the call.
    /// @param futureValues A closure that returns a source that triggers whenever the observable changes.
    public init(getter: @escaping (Void) -> Value, futureValues: @escaping (Void) -> Source<Value>) {
        self.getter = getter
        self.valueSource = futureValues
    }

    /// The current value of the observable.
    public var value: Value { return getter() }

    public var futureValues: Source<Value> { return valueSource() }
}

public extension ObservableType {
    /// Creates a constant observable wrapping the given value. The returned observable is not modifiable and it will not ever send updates.
    public static func constant(_ value: Value) -> Observable<Value> {
        return Observable(getter: { value }, futureValues: { Source.emptySource() })
    }
}

public extension Updatable {
    public init(observable: Observable<Value>, setter: @escaping (Value) -> Void) {
        self.init(getter: observable.getter, setter: setter, futureValues: observable.valueSource)
    }
}
