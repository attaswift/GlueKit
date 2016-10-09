//
//  CompositeUpdatable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension UpdatableValueType {
    public func combined<Other: UpdatableValueType>(_ other: Other) -> Updatable<(Value, Other.Value)> {
        return CompositeUpdatable(first: self, second: other).updatable
    }

    public func combined<A: UpdatableValueType, B: UpdatableValueType>(_ a: A, _ b: B) -> Updatable<(Value, A.Value, B.Value)> {
        return combined(a).combined(b)
            .map({ a, b in (a.0, a.1, b) },
                 inverse: { v in ((v.0, v.1), v.2) })
    }

    public func combined<A: UpdatableValueType, B: UpdatableValueType, C: UpdatableValueType>(_ a: A, _ b: B, _ c: C) -> Updatable<(Value, A.Value, B.Value, C.Value)> {
        return combined(a).combined(b).combined(c)
        .map({ a, b in (a.0.0, a.0.1, a.1, b) },
             inverse: { v in (((v.0, v.1), v.2), v.3) })
    }

    public func combined<A: UpdatableValueType, B: UpdatableValueType, C: UpdatableValueType, D: UpdatableValueType>(_ a: A, _ b: B, _ c: C, _ d: D) -> Updatable<(Value, A.Value, B.Value, C.Value, D.Value)> {
        return combined(a).combined(b).combined(c).combined(d)
            .map({ a, b in (a.0.0.0, a.0.0.1, a.0.1, a.1, b) },
                 inverse: { v in ((((v.0, v.1), v.2), v.3), v.4) })
    }

    public func combined<A: UpdatableValueType, B: UpdatableValueType, C: UpdatableValueType, D: UpdatableValueType, E: UpdatableValueType>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> Updatable<(Value, A.Value, B.Value, C.Value, D.Value, E.Value)> {
        return combined(a).combined(b).combined(c).combined(d).combined(e)
            .map({ a, b in (a.0.0.0.0, a.0.0.0.1, a.0.0.1, a.0.1, a.1, b) },
                 inverse: { v in (((((v.0, v.1), v.2), v.3), v.4), v.5) })
    }
}

/// An Updatable that is a composite of two other updatables.
private final class CompositeUpdatable<A: UpdatableValueType, B: UpdatableValueType>: UpdatableValueType, SignalDelegate {
    typealias Value = (A.Value, B.Value)
    private let first: A
    private let second: B
    private var signal = OwningSignal<SimpleChange<Value>>()

    private var firstValue: A.Value? = nil
    private var secondValue: B.Value? = nil
    private var connections: (Connection, Connection)? = nil
    private var updating = 0

    init(first: A, second: B) {
        self.first = first
        self.second = second
    }

    final var changes: Source<SimpleChange<Value>> { return signal.with(self).source }

    final var value: Value {
        get {
            if let v1 = firstValue, let v2 = secondValue { return (v1, v2) }
            return (first.value, second.value)
        }
        set {
            if let v1 = firstValue, let v2 = secondValue {
                // Updating a composite updatable is tricky, because updating the components will trigger a synchronous update,
                // which can lead to us broadcasting intermediate states, which can result in infinite feedback loops.
                // This simple workaround solves the simplest cases.
                updating += 1
                let old = (v1, v2)
                first.value = newValue.0
                second.value = newValue.1
                updating -= 1
                if updating == 0 {
                    signal.send(.init(from: old, to: (firstValue!, secondValue!)))
                }
            }
            else {
                first.value = newValue.0
                second.value = newValue.1
            }
        }
    }

    final func start(_ signal: Signal<SimpleChange<Value>>) {
        precondition(connections == nil)
        firstValue = first.value
        secondValue = second.value
        let c1 = first.changes.connect { [unowned self] change in
            if self.updating > 0 {
                self.firstValue = change.new
            }
            else {
                let old = (change.old, self.secondValue!)
                let new = (change.new, self.secondValue!)
                self.firstValue = change.new
                signal.send(SimpleChange(from: old, to: new))
            }
        }
        let c2 = second.changes.connect { [unowned self] change in
            if self.updating > 0 {
                self.secondValue = change.new
            }
            else {
                let old = (self.firstValue!, change.old)
                let new = (self.firstValue!, change.new)
                self.secondValue = change.new
                signal.send(SimpleChange(from: old, to: new))
            }
        }
        connections = (c1, c2)
    }

    final func stop(_ signal: Signal<SimpleChange<Value>>) {
        connections!.0.disconnect()
        connections!.1.disconnect()
        firstValue = nil
        secondValue = nil
        connections = nil
    }
}
