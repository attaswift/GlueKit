//
//  Observable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public protocol ChangeType {
    typealias Value

    init(oldValue: Value, newValue: Value)
    func applyOn(value: Value) -> Value
}

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

    /// A source that, for each new sink, immediately sends the current value, and thereafter delivers updated values.
    var values: Source<Change.Value> { get } // Implemented in an extension in terms of futureValues and value.
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
    /// A source that immediately sends the current value to each new sink, and thereafter delivers new values
    /// whenever this readable changes.
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
                    sink(value)
                }
            }
            while !(pendingValues!.isEmpty) {
                sink(pendingValues!.removeFirst())
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
    /// The getter closure for the current value of this observable.
    public let getter: Void -> Change.Value

    /// A source providing the values of future updates to this observable.
    public let futureChanges: Source<Change>
    public let futureValues: Source<Change.Value>
    public let values: Source<Change.Value>

    /// Initializes an Observable from the given getter closure and source of future changes.
    /// @param getter A closure that returns the current value of the observable at the time of the call.
    /// @param futureSource A source that triggers whenever the observable changes.
    public init
        <FCS: SourceType, FVS: SourceType, VS: SourceType where FCS.SourceValue == Change, FVS.SourceValue == Change.Value, VS.SourceValue == Change.Value>
        (getter: Void->Change.Value, futureChanges: FCS, futureValues: FVS, values: VS) {
        self.getter = getter
        self.futureChanges = futureChanges.source
        self.futureValues = futureValues.source
        self.values = values.source
    }

    public init<Observable: ObservableType where Observable.Change == Change>(_ observable: Observable) {
        self.getter = { observable.value }
        self.futureChanges = observable.futureChanges
        self.futureValues = observable.futureValues
        self.values = observable.values
    }

    /// The current value of the observable.
    public var value: Change.Value { return getter() }
}
