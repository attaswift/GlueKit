//
//  SourceOperators.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

extension SourceType {
    /// Returns a source that, applies `transform` on each value produced by `self` and each subscriber sink.
    ///
    /// `transform` should be a pure function, i.e., one with no side effects or hidden parameters.
    /// For each value that is received from `self`, it is called as many times as there are subscribers.
    public func sourceOperator<Result>(_ type: Result.Type = Result.self, _ transform: @escaping (Value, (Result) -> Void) -> Void) -> AnySource<Result> {
        return SourceOperator(input: self, transform: transform).anySource
    }
}

class TransformedSource<Input: SourceType, Value>: _AbstractSource<Value> {
    let input: Input

    init(input: Input) {
        self.input = input
    }

    final override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        self.input.add(TransformedSink(source: self, sink: sink))
    }

    @discardableResult
    final override func remove<Sink: SinkType>(_ sink: Sink) -> AnySink<Value> where Sink.Value == Value {
        typealias TSink = TransformedSink<Input, Sink>
        let old: TSink = self.input.remove(TSink(source: self, sink: sink)).opened()!
        return old.sink.anySink
    }

    func receive<Sink: SinkType>(_ value: Input.Value, for sink: Sink) where Sink.Value == Value { abstract() }
}

private struct TransformedSink<Input: SourceType, Sink: SinkType>: SinkType {
    typealias Value = Input.Value

    unowned let source: TransformedSource<Input, Sink.Value>
    let sink: Sink

    init(source: TransformedSource<Input, Sink.Value>, sink: Sink) {
        self.source = source
        self.sink = sink
    }

    func receive(_ value: Input.Value) {
        source.receive(value, for: sink)
    }

    var hashValue: Int {
        return Int.baseHash.mixed(with: ObjectIdentifier(source)).mixed(with: sink)
    }

    static func ==(left: TransformedSink, right: TransformedSink) -> Bool {
        return left.source === right.source && left.sink == right.sink
    }
}

class SourceOperator<Input: SourceType, Value>: TransformedSource<Input, Value> {
    let transform: (Input.Value, (Value) -> Void) -> Void

    init(input: Input, transform: @escaping (Input.Value, (Value) -> Void) -> Void) {
        self.transform = transform
        super.init(input: input)
    }

    override func receive<Sink: SinkType>(_ value: Input.Value, for sink: Sink) where Sink.Value == Value {
        transform(value, sink.receive)
    }
}

extension SourceType {
    public func map<Output>(_ transform: @escaping (Value) -> Output) -> AnySource<Output> {
        return MappedSource(input: self, transform: transform).anySource
    }
}

private class MappedSource<Input: SourceType, Value>: TransformedSource<Input, Value> {
    let transform: (Input.Value) -> Value

    init(input: Input, transform: @escaping (Input.Value) -> Value) {
        self.transform = transform
        super.init(input: input)
    }

    override func receive<Sink: SinkType>(_ value: Input.Value, for sink: Sink) where Sink.Value == Value {
        sink.receive(transform(value))
    }
}


extension SourceType {
    public func filter(_ predicate: @escaping (Value) -> Bool) -> AnySource<Value> {
        return FilteredSource(input: self, filter: predicate).anySource
    }
}

private class FilteredSource<Input: SourceType>: TransformedSource<Input, Input.Value> {
    let filter: (Input.Value) -> Bool

    init(input: Input, filter: @escaping (Input.Value) -> Bool) {
        self.filter = filter
        super.init(input: input)
    }

    override func receive<Sink: SinkType>(_ value: Input.Value, for sink: Sink) where Sink.Value == Input.Value {
        if filter(value) {
            sink.receive(value)
        }
    }
}


extension SourceType {
    public func flatMap<Output>(_ transform: @escaping (Value) -> Output?) -> AnySource<Output> {
        return NonNilSource(input: self, transform: transform).anySource
    }
}

private class NonNilSource<Input: SourceType, Value>: TransformedSource<Input, Value> {
    let transform: (Input.Value) -> Value?

    init(input: Input, transform: @escaping (Input.Value) -> Value?) {
        self.transform = transform
        super.init(input: input)
    }

    override func receive<Sink: SinkType>(_ value: Input.Value, for sink: Sink) where Sink.Value == Value {
        if let output = transform(value) {
            sink.receive(output)
        }
    }
}

extension SourceType {
    public func flatMap<Output>(_ transform: @escaping (Value) -> [Output]) -> AnySource<Output> {
        return FlattenedSource(input: self, transform: transform).anySource
    }
}

private class FlattenedSource<Input: SourceType, Value>: TransformedSource<Input, Value> {
    let transform: (Input.Value) -> [Value]

    init(input: Input, transform: @escaping (Input.Value) -> [Value]) {
        self.transform = transform
        super.init(input: input)
    }

    override func receive<Sink: SinkType>(_ value: Input.Value, for sink: Sink) where Sink.Value == Value {
        for v in transform(value) {
            sink.receive(v)
        }
    }
}

