//
//  ChangeType.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-12.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

/// Describes a change to an observable value.
/// An instance of a type implementing this protocol contains just enough information to describe the difference
/// between the old value and the new value of the observable.
public protocol ChangeType {
    associatedtype Value

    /// Creates a new change description for a change that goes from `oldValue` to `newValue`.
    init(from oldValue: Value, to newValue: Value)

    /// Returns true if this change did not actually change the value of the observable.
    /// Noop changes aren't usually sent by observables, but it is possible to get them by merging a sequence of
    /// changes to a collection.
    var isEmpty: Bool { get }

    /// Applies this change on `value` in place.
    /// Note that not all changes may be applicable on all values.
    func apply(on value: inout Value)

    /// Applies this change on `value` and returns the result.
    /// Note that not all changes may be applicable on all values.
    func applied(on value: Value) -> Value

    /// Merge this change with the `next` change. The result is a single change description that describes the
    /// change of performing `self` followed by `next`.
    ///
    /// The resulting instance may take a shortcut when producing the result value if some information in `self`
    /// is overwritten by `next`.
    func merged(with next: Self) -> Self

    mutating func merge(with next: Self)

    /// Reverse the direction of this change, i.e., return a change that undoes the effect of this change.
    func reversed() -> Self
}


extension ChangeType {
    /// Applies this change on `value` and returns the result.
    /// Note that not all changes may be applicable on all values.
    public func applied(on value: Value) -> Value {
        var result = value
        self.apply(on: &result)
        return result
    }

    public func merged(with next: Self) -> Self {
        var temp = self
        temp.merge(with: next)
        return temp
    }
}

public enum ChangeEvent<Change: ChangeType> {
    case willChange
    case didNotChange
    case didChange(Change)

}

extension ChangeEvent {
    public var change: Change? {
        if case let .didChange(change) = self { return change }
        return nil
    }

    public func filter(_ test: (Change) -> Bool) -> ChangeEvent<Change> {
        switch self {
        case .willChange, .didNotChange:
            return self
        case .didChange(let change):
            if test(change) {
                return self
            }
            return .didNotChange
        }
    }

    public func map<Result: ChangeType>(_ transform: (Change) -> Result) -> ChangeEvent<Result> {
        switch self {
        case .willChange:
            return .willChange
        case .didNotChange:
            return .didNotChange
        case .didChange(let change):
            return .didChange(transform(change))
        }
    }
}

private class _ChangeSignal<Change: ChangeType>: Signal<ChangeEvent<Change>> {
    typealias SourceValue = ChangeEvent<Change>
    var pendingCount = 0
    var pendingChange: Change? = nil

    override func connect(_ sink: Sink<SourceValue>) -> Connection {
        if self.pendingCount > 0 {
            sink.receive(.willChange)
        }
        let c = super.connect(sink)
        c.addCallback { id in
            if self.pendingCount > 0 {
                if let change = self.pendingChange {
                    sink.receive(.didChange(change))
                }
                else {
                    sink.receive(.didNotChange)
                }
            }
        }
        return c
    }
}

struct ChangeSignal<Change: ChangeType> {
    typealias SourceValue = ChangeEvent<Change>

    private weak var signal: _ChangeSignal<Change>? = nil

    mutating func source(holding owner: AnyObject) -> Source<SourceValue> {
        if let signal = self.signal { return signal.source }
        let signal = _ChangeSignal<Change>(delegateCallback: { _, _ in _ = owner })
        self.signal = signal
        return signal.source
    }

    mutating func source<D: SignalDelegate>(holdingDelegate delegate: D) -> Source<SourceValue> where D.SignalValue == SourceValue {
        if let signal = self.signal { return signal.source }
        let signal = _ChangeSignal<Change>(stronglyHeldDelegate: delegate)
        self.signal = signal
        return signal.source
    }


    var isConnected: Bool { return signal?.isConnected ?? false }
    var isChanging: Bool { return signal?.pendingCount != 0 }

    var isActive: Bool {
        guard let signal = self.signal else { return false }
        return signal.isConnected || signal.pendingCount > 0
    }

    func willChange() {
        guard let signal = signal else { return }
        signal.pendingCount += 1
        if signal.pendingCount == 1 {
            signal.send(.willChange)
        }
    }

    func didNotChange() {
        guard let signal = signal else { return }
        precondition(signal.pendingCount > 0)
        signal.pendingCount -= 1
        if signal.pendingCount == 0 {
            if let c = signal.pendingChange {
                signal.pendingChange = nil
                signal.send(.didChange(c))
            }
            else {
                signal.send(.didNotChange)
            }
        }
    }

    func didChange(_ change: Change) {
        guard let signal = signal else { return }
        precondition(signal.pendingCount > 0)
        signal.pendingCount -= 1
        if signal.pendingCount == 0 {
            if var c = signal.pendingChange {
                signal.pendingChange = nil
                c.merge(with: change)
                signal.send(.didChange(c))
            }
            else {
                signal.send(.didChange(change))
            }
        }
        else {
            if var c = signal.pendingChange {
                signal.pendingChange = nil
                c.merge(with: change)
                signal.pendingChange = c
            }
            else {
                signal.pendingChange = change
            }
        }
    }

    func send(_ event: ChangeEvent<Change>) {
        switch event {
        case .willChange: willChange()
        case .didNotChange: didNotChange()
        case .didChange(let change): didChange(change)
        }
    }
}

