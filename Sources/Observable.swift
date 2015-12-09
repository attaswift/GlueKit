//
//  Observable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// Describes a change of an Observable.
public protocol ChangeType {
    typealias Value

    /// Creates a new change description from `oldValue` to `newValue`.
    init(oldValue: Value, newValue: Value)

    /// Applies this change on `value`, returning the new value.
    /// `value` must have been created by loading the value before the change, 
    /// or by applying the previous change to a previous valid value.
    func applyOn(value: Value) -> Value
}

/// Describes a change simply by including both the previous and the new value.
public struct SimpleChange<Value>: ChangeType {
    public let oldValue: Value
    public let newValue: Value

    public init(oldValue: Value, newValue: Value) {
        self.oldValue = oldValue
        self.newValue = newValue
    }

    public func applyOn(value: Value) -> Value {
        return newValue
    }
}

/// A type implementing ObservableType has a current value and provides two Sources to observe changes to it.
/// ObservableTypes are generally not type-safe; you must serialize all accesses to them 
/// (including connecting to any of their sources).
public protocol ObservableType {
    typealias ObservableValue = Change.Value
    typealias Change: ChangeType // Typically SimpleChangeType<ObservableValue>, but see ArrayVariable

    /// The current value of this observable.
    var value: Change.Value { get }

    /// A source that delivers `(oldValue, newValue)` pairs whenever this observable changes.
    var futureChanges: Source<Change> { get }

    /// A source that delivers the new value whenever this observable changes.
    var futureValues: Source<Change.Value> { get } // Implemented in an extension in terms of futureChanges.
}

extension ObservableType where Change == SimpleChange<ObservableValue> {

    /// A source that delivers the new value whenever this observable changes.
    public var futureValues: Source<Change.Value> {
        return futureChanges.map { $0.newValue }
    }

    /// Returns the type-lifted version of this ObservableType.
    public var observable: Observable<Change.Value> {
        return Observable<Change.Value>(getter: { self.value }, futureChanges: { self.futureChanges })
    }
}

extension ObservableType {
    /// A source that, for each new sink, immediately sends the current value, and thereafter delivers updated values, 
    /// like `futureValues`. Implemented in terms of `futureValues` and `value`.
    public var values: Source<Change.Value> {
        return Source<Change.Value> { sink in
            // We assume connections not concurrent with updates.
            // However, reentrant updates from a sink are fully supported -- they are serialized below.
            var pendingValues: [Change.Value]? = [self.value]
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
    public typealias Change = SimpleChange<Value>

    /// The getter closure for the current value of this observable.
    private let getter: Void -> Change.Value

    /// A closure providing a source providing the values of future updates to this observable.
    private let _futureChanges: Void -> Source<Change>

    /// Initializes an Observable from the given getter closure and source of future changes.
    /// @param getter A closure that returns the current value of the observable at the time of the call.
    /// @param futureSource A closure that returns a source that triggers whenever the observable changes.
    public init(getter: Void->Change.Value, futureChanges: Void -> Source<Change>) {
        self.getter = getter
        self._futureChanges = futureChanges
    }

    /// The current value of the observable.
    public var value: Value { return getter() }

    /// The source providing the values of future updates to this observable.
    public var futureChanges: Source<Change> { return _futureChanges() }
}

/// The type lifted representation of an ObservableType that contains a value with complex changes.
public struct AnyObservable<Change: ChangeType>: ObservableType {
    public typealias Value = Change.Value

    private let _getter: Void -> Change.Value
    private let _futureChanges: Void -> Source<Change>
    private let _futureValues: Void -> Source<Value>

    public init<Observable: ObservableType where Observable.Change == Change>(_ observable: Observable) {
        self._getter = { observable.value }
        self._futureChanges = { observable.futureChanges }
        self._futureValues = { observable.futureValues }
    }

    /// The current value of the observable.
    public var value: Value { return _getter() }

    public var futureChanges: Source<Change> { return _futureChanges() }
    public var futureValues: Source<Value> { return _futureValues() }
}
