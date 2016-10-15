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
    typealias Change = SimpleChange<Value>

    private let first: A
    private let second: B
    private var latest: Value? = nil
    private var signal = ChangeSignal<Change>()
    private var state: ObservableStateForTwoDependencies<Value> = .normal
    private var connections: (Connection, Connection)? = nil

    init(first: A, second: B) {
        self.first = first
        self.second = second
    }

    func get() -> Value {
        if let latest = self.latest { return latest }
        return (first.get(), second.get())
    }

    func update(_ body: (Value) -> Value) {
        first.update { a in
            var result: Value? = nil
            second.update { b in
                result = body((a, b))
                return result!.1
            }
            return result!.0
        }
    }

    final var changeEvents: Source<ChangeEvent<Change>> { return signal.source(holdingDelegate: self) }

    final var value: Value {
        get {
            return get()
        }
        set {
            first.update { _ in
                second.update { _ in
                    return newValue.1
                }
                return newValue.0
            }
        }
    }

    final func start(_ signal: Signal<ChangeEvent<Change>>) {
        precondition(connections == nil)
        latest = (first.get(), second.get())
        let c1 = first.changeEvents.connect { [unowned self] event in
            let followup = self.state.applyEventFromFirst(self.latest!, event)
            if let change = event.change {
                self.latest!.0 = change.new
            }
            if let event = followup.with(new: self.latest!) {
                signal.send(event)
            }
        }
        let c2 = second.changeEvents.connect { [unowned self] event in
            let followup = self.state.applyEventFromFirst(self.latest!, event)
            if let change = event.change {
                self.latest!.1 = change.new
            }
            if let event = followup.with(new: self.latest!) {
                signal.send(event)
            }
        }
        connections = (c1, c2)
    }

    final func stop(_ signal: Signal<ChangeEvent<Change>>) {
        connections!.0.disconnect()
        connections!.1.disconnect()
        connections = nil
        latest = nil
    }
}
