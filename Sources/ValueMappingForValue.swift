//
//  ValueMappingForValue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2015–2017 Károly Lőrentey.
//

public extension ObservableValueType {
    /// Returns an observable that calculates `transform` on all current and future values of this observable.
    public func map<Output>(_ transform: @escaping (Value) -> Output) -> AnyObservableValue<Output> {
        return ValueMappingForValue<Self, Output>(parent: self, transform: transform).anyObservableValue
    }
}

private final class ValueMappingForValue<Parent: ObservableValueType, Value>: _AbstractObservableValue<Value> {
    let parent: Parent
    let transform: (Parent.Value) -> Value
    let sinkTransform: SinkTransformFromMapping<ValueUpdate<Parent.Value>, ValueUpdate<Value>>

    init(parent: Parent, transform: @escaping (Parent.Value) -> Value) {
        self.parent = parent
        self.transform = transform
        self.sinkTransform = SinkTransformFromMapping { u in u.map { c in c.map(transform) } }
    }

    override var value: Value {
        return transform(parent.value)
    }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        parent.add(TransformedSink(sink: sink, transform: sinkTransform))
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return parent.remove(TransformedSink(sink: sink, transform: sinkTransform)).sink
    }
}

extension UpdatableValueType {
    public func map<Output>(_ transform: @escaping (Value) -> Output, inverse: @escaping (Output) -> Value) -> AnyUpdatableValue<Output> {
        return ValueMappingForUpdatableValue<Self, Output>(parent: self, transform: transform, inverse: inverse).anyUpdatableValue
    }
}

private final class ValueMappingForUpdatableValue<Parent: UpdatableValueType, Value>: _AbstractUpdatableValue<Value> {
    let parent: Parent
    let transform: (Parent.Value) -> Value
    let inverse: (Value) -> Parent.Value
    let sinkTransform: SinkTransformFromMapping<ValueUpdate<Parent.Value>, ValueUpdate<Value>>

    init(parent: Parent, transform: @escaping (Parent.Value) -> Value, inverse: @escaping (Value) -> Parent.Value) {
        self.parent = parent
        self.transform = transform
        self.inverse = inverse
        self.sinkTransform = SinkTransformFromMapping { u in u.map { c in c.map(transform) } }
    }

    override var value: Value {
        get {
            return transform(parent.value)
        }
        set {
            parent.value = inverse(newValue)
        }
    }

    override func apply(_ update: Update<ValueChange<Value>>) {
        parent.apply(update.map { change in change.map(inverse) })
    }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        parent.add(TransformedSink(sink: sink, transform: sinkTransform))
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return parent.remove(TransformedSink(sink: sink, transform: sinkTransform)).sink
    }
}
