//
//  SourceOperators.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

class TransformedSource<Input: SourceType, Value>: _AbstractSource<Value> {
    let input: Input

    init(input: Input) {
        self.input = input
    }

    final override func add<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Value {
        return self.input.add(TransformedSink(source: self, sink: sink))
    }

    final override func remove<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Value {
        return self.input.remove(TransformedSink(source: self, sink: sink))
    }

    func receive<Sink: SinkType>(_ value: Input.Value, for sink: Sink) where Sink.Value == Value {
        abstract()
    }
}

private struct TransformedSink<Input: SourceType, Sink: SinkType>: SinkType {
    typealias Value = Input.Value

    let _source: TransformedSource<Input, Sink.Value>
    let _sink: Sink

    init(source: TransformedSource<Input, Sink.Value>, sink: Sink) {
        _source = source
        _sink = sink
    }

    func receive(_ value: Input.Value) {
        _source.receive(value, for: _sink)
    }

    var hashValue: Int {
        return Int.baseHash.mixed(with: ObjectIdentifier(_source)).mixed(with: _sink)
    }

    static func ==(left: TransformedSink, right: TransformedSink) -> Bool {
        return left._source === right._source && left._sink == right._sink
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

