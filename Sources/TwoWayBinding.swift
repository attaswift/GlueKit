//
//  TwoWayBinding.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-24.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension UpdatableValueType where Change == ValueChange<Value> {
    /// Create a two-way binding from self to a target updatable. The target is updated to the current value of self.
    /// All future updates will be synchronized between the two variables until the returned connection is disconnected.
    /// To prevent infinite cycles, you must provide an equality test that returns true if two values are to be
    /// considered equivalent.
    public func bind<Target: UpdatableValueType>(_ target: Target, by areEquivalent: @escaping (Value, Value) -> Bool) -> Connection where Target.Value == Value, Target.Change == ValueChange<Value> {
        return BindConnection(source: self, target: target, by: areEquivalent)
    }
}

class BindSink<Target: UpdatableValueType>: SinkType where Target.Change == ValueChange<Target.Value> {
    typealias Value = Target.Value
    let target: Target
    let areEquivalent: (Value, Value) -> Bool

    init(target: Target, by areEquivalent: @escaping (Value, Value) -> Bool) {
        self.target = target
        self.areEquivalent = areEquivalent
    }

    func receive(_ value: Value) {
        if !areEquivalent(value, target.value) {
            target.value = value
        }
    }
}

class BindConnection<Source: UpdatableValueType, Target: UpdatableValueType>: Connection
where Source.Value == Target.Value, Source.Change == ValueChange<Source.Value>, Target.Change == ValueChange<Target.Value> {
    typealias Value = Source.Value

    let source: Source
    let target: Target
    let forwardSink: BindSink<Target>
    let backwardSink: BindSink<Source>

    init(source: Source, target: Target, by areEquivalent: @escaping (Value, Value) -> Bool) {
        self.source = source
        self.target = target
        self.forwardSink = BindSink(target: target, by: areEquivalent)
        self.backwardSink = BindSink(target: source, by: areEquivalent)

        source.futureValues.add(self.forwardSink)
        target.futureValues.add(self.backwardSink)
        if !areEquivalent(source.value, target.value) {
            target.value = source.value
        }
    }

    deinit {
        disconnect()
    }

    override func disconnect() {
        source.futureValues.remove(forwardSink)
        target.futureValues.remove(backwardSink)
    }
}

extension UpdatableValueType where Value: Equatable, Change == ValueChange<Value> {
    /// Create a two-way binding from self to a target variable. The target is updated to the current value of self.
    /// All future updates will be synchronized between the two variables until the returned connection is disconnected.
    /// To prevent infinite cycles, the variables aren't synched when a bound variable is set to a value that is equal
    /// to the value of its counterpart.
    public func bind<Target: UpdatableValueType>(_ target: Target) -> Connection where Target.Value == Value, Target.Change == ValueChange<Value> {
        return self.bind(target, by: ==)
    }
}

extension Connector {
    public func bind<Source: UpdatableValueType, Target: UpdatableValueType>(_ source: Source, to target: Target, by areEquivalent: @escaping (Source.Value, Source.Value) -> Bool)
        where Source.Value == Target.Value, Source.Change == ValueChange<Source.Value>, Target.Change == ValueChange<Target.Value> {
            source.bind(target, by: areEquivalent).putInto(self)
    }

    public func bind<Value: Equatable, Source: UpdatableValueType, Target: UpdatableValueType>(_ source: Source, to target: Target)
        where Source.Value == Value, Target.Value == Value, Source.Change == ValueChange<Source.Value>, Target.Change == ValueChange<Target.Value> {
            source.bind(target).putInto(self)
    }
}
