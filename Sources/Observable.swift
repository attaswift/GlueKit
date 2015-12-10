//
//  Observable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// Describes a change of an `Observable`. An instance of a type implementing this protocol contains just enough
/// information to reproduce the result of the change from the previous value of the observable.
///
/// This is trivially implemented by `SimpleChange` for simple value types, but it is considerably more complex
/// for collections.
///
/// - SeeAlso: Observable, SimpleChange, ArrayChange
public protocol ChangeType {
    typealias Value

    /// Creates a new change description for a change that goes from `oldValue` to `newValue`.
    init(from oldValue: Value, to newValue: Value)

    /// Returns true if this change did not actually change the value of the observable.
    /// Noop changes aren't usually sent by observables, but it is possible to get them by merging a sequence of 
    /// changes to a collection.
    var isNull: Bool { get }

    /// Applies this change on `value`, returning the new value.
    /// Note that `value` must be the same value as the one this change was created from.
    func applyOn(value: Value) -> Value

    /// Merge this change with the `next` change. The result is a single change description that describes the
    /// change of performing `self` followed by `next`.
    ///
    /// The resulting instance may take a shortcut when producing the result value if some information in `self` 
    /// is overwritten by `next`.
    func merge(next: Self) -> Self
}

/// Describes a change to the value of an `Observable` by simply including the new value in its entirety.
public struct SimpleChange<Value>: ChangeType {
    /// The value resulting from this change.
    public let value: Value

    /// Initializes a new `SimpleChange` with `value` as the change result.
    public init(_ value: Value) {
        self.value = value
    }

    /// Initializes a new `SimpleChange` containing `newValue`. `oldValue` is discarded.
    public init(from oldValue: Value, to newValue: Value) {
        self.value = newValue
    }

    /// A `SimpleChange` is never a noop, so this property is always false.
    public var isNull: Bool { return false }

    /// Applies this change on `value`, returning the new value.
    ///
    /// `SimpleChange` ignores the supplied `value` and simply returns the value contained in `self.value`.
    public func applyOn(value: Value) -> Value {
        return self.value
    }

    /// Merge this change with the `next` change. The result is a single change description that describes the
    /// change of performing `self` followed by `next`.
    ///
    /// Concatenating two `SimpleChange`s has the same result as discarding the first and simply applying the second one.
    public func merge(next: SimpleChange<Value>) -> SimpleChange<Value> {
        return next
    }
}

/// An observable has a value that is readable at any time, and may change in response to certain events.
/// Interested parties can sign up to receive notifications when the observable's value changes.
///
/// In GlueKit, observables are represented by types implementing `ObservableType`. They provide update notifications
/// via any of several sources:
///
/// - `values` sends the initial value of the observable to each new sink, followed by the values of later updates.
/// - `futureValues` skips the initial value and just sends values on future updates.
/// - `futureChanges` sends a description of each change of the variable.
///
/// Of these, the `values` source is often the most convenient to work with, while `futureChanges` often provides a
/// significant performance boost. (Especially when the observable models a collection, like `ArrayVariable`.)
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
    typealias Change: ChangeType
    typealias ObservableValue = Change.Value

    /// The current value of this observable.
    var value: Change.Value { get }

    /// A source that delivers diffs whenever this observable changes.
    var futureChanges: Source<Change> { get }

    /// A source that delivers new values whenever this observable changes.
    ///
    /// This source is implemented in a protocol extension in terms of futureChanges, but it is provided here
    /// to let concrete observables supply their own, more efficient versions.
    var futureValues: Source<Change.Value> { get }
}

extension ObservableType {
    /// A source that delivers new values whenever this observable changes.
    ///
    /// This is the most generic implementation of `futureValues`.
    /// It keeps a copy of the "current" value of the observable in order to apply changes on it.
    public var futureValues: Source<Change.Value> {
        var connection: Connection? = nil
        var value: Change.Value? = nil
        let signal = Signal<Change.Value> { signal, started in
            if started {
                value = self.value
                connection = self.futureChanges.connect { change in
                    value = change.applyOn(value!)
                    signal.send(value!)
                }
            }
            else {
                connection?.disconnect()
                value = nil
                connection = nil
            }
        }
        return signal.source
    }
}

extension ObservableType where Change == SimpleChange<ObservableValue> {

    /// A source that delivers new values whenever this observable changes.
    ///
    /// When changes are represented by `SimpleChange`, this is simply a matter of extracting the new value from the change descriptor.
    public var futureValues: Source<Change.Value> {
        return futureChanges.map { $0.value }
    }

    /// Returns the type-lifted version of this ObservableType.
    public var observable: Observable<Change.Value> {
        return Observable<Change.Value>(getter: { self.value }, futureValues: { self.futureValues })
    }
}

extension ObservableType {
    /// A source that, for each new sink, immediately sends it the current value, and thereafter delivers updated values,
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
    private let _getter: Void -> Value

    /// A closure providing a source providing the values of future updates to this observable.
    private let _futureValues: Void -> Source<Value>

    /// Initializes an Observable from the given getter closure and source of future changes.
    /// @param getter A closure that returns the current value of the observable at the time of the call.
    /// @param futureSource A closure that returns a source that triggers whenever the observable changes.
    public init(getter: Void->Value, futureValues: Void -> Source<Value>) {
        self._getter = getter
        self._futureValues = futureValues
    }

    /// The current value of the observable.
    public var value: Value { return _getter() }

    public var futureValues: Source<Change.Value> { return _futureValues() }

    /// The source providing the values of future updates to this observable.
    public var futureChanges: Source<Change> { return _futureValues().map { SimpleChange($0) } }
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

public extension ObservableType {
    /// Creates a constant observable wrapping the given value. The returned observable is not modifiable and it will not ever send updates.
    public static func constant(value: Change.Value) -> Observable<Change.Value> {
        return Observable(getter: { value }, futureValues: { Source.emptySource() })
    }
}
