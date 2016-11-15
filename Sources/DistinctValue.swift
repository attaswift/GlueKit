//
//  DistinctValue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import SipHash

private class DistinctSinkState<V> {
    typealias Value = ValueUpdate<V>

    let areEquivalent: (V, V) -> Bool
    var pending: ValueChange<V>? = nil

    init(_ areEquivalent: @escaping (V, V) -> Bool) {
        self.areEquivalent = areEquivalent
    }

    fileprivate func applyUpdate<Sink: SinkType>(_ update: Value, _ sink: Sink) where Sink.Value == Value {
        switch update {
        case .beginTransaction:
            precondition(pending == nil)
            sink.receive(update)
        case .change(let change):
            if pending == nil {
                pending = change
            }
            else {
                pending!.merge(with: change)
            }
        case .endTransaction:
            if let change = pending, !areEquivalent(change.old, change.new) {
                sink.receive(.change(change))
            }
            pending = nil
            sink.receive(update)
        }
    }
}

private struct DistinctSink<V, Sink: SinkType>: SinkType, SipHashable where Sink.Value == ValueUpdate<V> {
    typealias Value = ValueUpdate<V>

    let owner: AnyObject
    let sink: Sink
    let state: DistinctSinkState<V>?

    func receive(_ update: Value) {
        state?.applyUpdate(update, sink)
    }

    func appendHashes(to hasher: inout SipHasher) {
        hasher.append(ObjectIdentifier(owner))
        hasher.append(sink)
    }

    static func ==(left: DistinctSink, right: DistinctSink) -> Bool {
        return left.owner === right.owner && left.sink == right.sink
    }
}

public extension ObservableValueType where Change == ValueChange<Value> {
    public func distinct(_ areEquivalent: @escaping (Value, Value) -> Bool) -> AnyObservableValue<Value> {
        return DistinctObservableValue(self, by: areEquivalent).anyObservableValue
    }
}

public extension ObservableValueType where Change == ValueChange<Value>, Value: Equatable {
    public func distinct() -> AnyObservableValue<Value> {
        return distinct(==)
    }
}

private class DistinctObservableValue<Input: ObservableValueType>: _AbstractObservableValue<Input.Value> where Input.Change == ValueChange<Input.Value> {
    typealias Value = Input.Value

    private let input: Input
    private let areEquivalent: (Value, Value) -> Bool

    init(_ input: Input, by areEquivalent: @escaping (Value, Value) -> Bool) {
        self.input = input
        self.areEquivalent = areEquivalent
    }

    override var value: Value {
        return input.value
    }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        input.add(DistinctSink(owner: self, sink: sink, state: DistinctSinkState(areEquivalent)))
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        let old = input.remove(DistinctSink(owner: self, sink: sink, state: nil))
        return old.sink
    }
}

public extension UpdatableValueType where Change == ValueChange<Value> {
    public func distinct(_ areEquivalent: @escaping (Value, Value) -> Bool) -> AnyUpdatableValue<Value> {
        return DistinctUpdatableValue(self, by: areEquivalent).anyUpdatableValue
    }
}

public extension UpdatableValueType where Change == ValueChange<Value>, Value: Equatable {
    public func distinct() -> AnyUpdatableValue<Value> {
        return distinct(==)
    }
}

private class DistinctUpdatableValue<Input: UpdatableValueType>: _AbstractUpdatableValue<Input.Value> where Input.Change == ValueChange<Input.Value> {
    typealias Value = Input.Value

    private let input: Input
    private let areEquivalent: (Value, Value) -> Bool

    init(_ input: Input, by areEquivalent: @escaping (Value, Value) -> Bool) {
        self.input = input
        self.areEquivalent = areEquivalent
    }

    override var value: Value {
        get {
            return input.value
        }
        set {
            input.value = newValue
        }
    }

    override func apply(_ update: ValueUpdate<Value>) {
        input.apply(update)
    }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        input.add(DistinctSink(owner: self, sink: sink, state: DistinctSinkState(areEquivalent)))
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        let old = input.remove(DistinctSink(owner: self, sink: sink, state: nil))
        return old.sink
    }
}
