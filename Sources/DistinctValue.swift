//
//  DistinctValue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

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

private struct DistinctSink<V, Sink: SinkType>: SinkType where Sink.Value == ValueUpdate<V> {
    typealias Value = ValueUpdate<V>

    let owner: AnyObject
    let sink: Sink
    let state: DistinctSinkState<V>?

    func receive(_ update: Value) {
        state?.applyUpdate(update, sink)
    }

    var hashValue: Int {
        return Int.baseHash.mixed(with: ObjectIdentifier(owner)).mixed(with: sink)
    }

    static func ==(left: DistinctSink, right: DistinctSink) -> Bool {
        return left.owner === right.owner && left.sink == right.sink
    }
}

private class DistinctUpdateSource<V>: _AbstractSource<ValueUpdate<V>> {
    typealias Value = ValueUpdate<V>

    let owner: AnyObject
    let areEquivalent: (V, V) -> Bool
    let target: AnySource<Value>

    init(owner: AnyObject, areEquivalent: @escaping (V, V) -> Bool, target: AnySource<ValueUpdate<V>>) {
        self.owner = owner
        self.areEquivalent = areEquivalent
        self.target = target
    }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        target.add(DistinctSink(owner: owner, sink: sink, state: DistinctSinkState(areEquivalent)))
    }

    override func remove<Sink: SinkType>(_ sink: Sink) -> AnySink<Value> where Sink.Value == Value {
        let old = target.remove(DistinctSink(owner: owner, sink: sink, state: nil))
        let opened = old.opened(as: DistinctSink<V, Sink>.self)!
        return opened.sink.anySink
    }
}

public extension ObservableValueType where Change == ValueChange<Value> {
    public func distinct(_ areEquivalent: @escaping (Value, Value) -> Bool) -> AnyObservableValue<Value> {
        return DistinctObservableValue(self, by: areEquivalent).anyObservable
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

    override var updates: ValueUpdateSource<Value> {
        return DistinctUpdateSource<Value>(owner: self, areEquivalent: areEquivalent, target: input.updates).anySource
    }
}

public extension UpdatableValueType where Change == ValueChange<Value> {
    public func distinct(_ areEquivalent: @escaping (Value, Value) -> Bool) -> AnyUpdatableValue<Value> {
        return DistinctUpdatableValue(self, by: areEquivalent).anyUpdatable
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

    override func apply(_ update: Update<ValueChange<Input.Value>>) {
        input.apply(update)
    }

    override var updates: ValueUpdateSource<Value> {
        return DistinctUpdateSource<Value>(owner: self, areEquivalent: areEquivalent, target: input.updates).anySource
    }
}
