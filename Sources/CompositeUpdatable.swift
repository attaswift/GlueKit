//
//  CompositeUpdatable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension UpdatableValueType where Change == ValueChange<Value> {
    public func combined<Other: UpdatableValueType>(_ other: Other) -> AnyUpdatableValue<(Value, Other.Value)> where Other.Change == ValueChange<Other.Value> {
        return CompositeUpdatable(left: self, right: other).anyUpdatable
    }

    public func combined<A: UpdatableValueType, B: UpdatableValueType>(_ a: A, _ b: B) -> AnyUpdatableValue<(Value, A.Value, B.Value)>
    where A.Change == ValueChange<A.Value>, B.Change == ValueChange<B.Value> {
        return combined(a).combined(b)
            .map({ a, b in (a.0, a.1, b) },
                 inverse: { v in ((v.0, v.1), v.2) })
    }

    public func combined<A: UpdatableValueType, B: UpdatableValueType, C: UpdatableValueType>(_ a: A, _ b: B, _ c: C) -> AnyUpdatableValue<(Value, A.Value, B.Value, C.Value)>
    where A.Change == ValueChange<A.Value>, B.Change == ValueChange<B.Value>, C.Change == ValueChange<C.Value> {
        return combined(a).combined(b).combined(c)
        .map({ a, b in (a.0.0, a.0.1, a.1, b) },
             inverse: { v in (((v.0, v.1), v.2), v.3) })
    }

    public func combined<A: UpdatableValueType, B: UpdatableValueType, C: UpdatableValueType, D: UpdatableValueType>(_ a: A, _ b: B, _ c: C, _ d: D) -> AnyUpdatableValue<(Value, A.Value, B.Value, C.Value, D.Value)>
    where A.Change == ValueChange<A.Value>, B.Change == ValueChange<B.Value>, C.Change == ValueChange<C.Value>, D.Change == ValueChange<D.Value> {
        return combined(a).combined(b).combined(c).combined(d)
            .map({ a, b in (a.0.0.0, a.0.0.1, a.0.1, a.1, b) },
                 inverse: { v in ((((v.0, v.1), v.2), v.3), v.4) })
    }

    public func combined<A: UpdatableValueType, B: UpdatableValueType, C: UpdatableValueType, D: UpdatableValueType, E: UpdatableValueType>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> AnyUpdatableValue<(Value, A.Value, B.Value, C.Value, D.Value, E.Value)>
    where A.Change == ValueChange<A.Value>, B.Change == ValueChange<B.Value>, C.Change == ValueChange<C.Value>, D.Change == ValueChange<D.Value>, E.Change == ValueChange<E.Value> {
        return combined(a).combined(b).combined(c).combined(d).combined(e)
            .map({ a, b in (a.0.0.0.0, a.0.0.0.1, a.0.0.1, a.0.1, a.1, b) },
                 inverse: { v in (((((v.0, v.1), v.2), v.3), v.4), v.5) })
    }
}

/// An AnyUpdatableValue that is a composite of two other updatables.
private final class CompositeUpdatable<Left: UpdatableValueType, Right: UpdatableValueType>: _BaseUpdatableValue<(Left.Value, Right.Value)>
where Left.Change == ValueChange<Left.Value>, Right.Change == ValueChange<Right.Value> {
    typealias Value = (Left.Value, Right.Value)
    typealias Change = ValueChange<Value>

    private let left: Left
    private let right: Right
    private var latest: Value? = nil

    init(left: Left, right: Right) {
        self.left = left
        self.right = right
    }

    override private func rawGetValue() -> Value {
        if let latest = self.latest { return latest }
        return (left.value, right.value)
    }

    override private func rawSetValue(_ value: Value) {
        left.apply(.beginTransaction)
        right.apply(.beginTransaction)
        left.value = value.0
        right.value = value.1
        right.apply(.endTransaction)
        left.apply(.endTransaction)
    }

    override func activate() {
        precondition(latest == nil)
        latest = (left.value, right.value)
        left.updates.add(StrongMethodSink(owner: self, identifier: 1, method: CompositeUpdatable.applyLeft))
        right.updates.add(StrongMethodSink(owner: self, identifier: 2, method: CompositeUpdatable.applyRight))
    }

    override func deactivate() {
        precondition(latest != nil)
        left.updates.remove(StrongMethodSink(owner: self, identifier: 1, method: CompositeUpdatable.applyLeft))
        right.updates.remove(StrongMethodSink(owner: self, identifier: 2, method: CompositeUpdatable.applyRight))
        latest = nil
    }

    private func applyLeft(_ update: ValueUpdate<Left.Value>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            let old = latest!
            latest!.0 = change.new
            sendChange(Change(from: old, to: latest!))
        case .endTransaction:
            endTransaction()
        }
    }

    private func applyRight(_ update: ValueUpdate<Right.Value>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            let old = latest!
            latest!.1 = change.new
            sendChange(Change(from: old, to: latest!))
        case .endTransaction:
            endTransaction()
        }
    }
}
