//
//  SourceOperators.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

struct TransformedSink<Input: SourceType, Sink: SinkType>: SinkType {
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
        return OptionalMappedSource(input: self, transform: transform).anySource
    }
}

private class OptionalMappedSource<Input: SourceType, Value>: TransformedSource<Input, Value> {
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

extension SourceType {
    public func buffered() -> AnySource<Value> {
        return BufferedSource(self).anySource
    }
}

private final class BufferedSource<Input: SourceType>: _AbstractSource<Input.Value>, SinkType {
    typealias Value = Input.Value

    private let _source: Input
    private let _signal = Signal<Value>()

    init(_ source: Input) {
        self._source = source
        super.init()
    }

    final override func add<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Value {
        let first = _signal.add(sink)
        if first {
            _source.add(self)
        }
        return first
    }

    final override func remove<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Value {
        let last = _signal.remove(sink)
        if last {
            _source.remove(self)
        }
        return last
    }

    func receive(_ value: Input.Value) {
        _signal.send(value)
    }
}

extension SourceType {
    /// Returns a version of this source that optionally prefixes or suffixes all observers' received values 
    /// with computed start/end values.
    ///
    /// For each new subscriber, the returned source evaluates `hello`; if it returns a non-nil value,
    /// the value is sent to the sink; then the sink is added to `self`.
    ///
    /// For each subscriber that is to be removed, the returned source first removes it from `self`, then 
    /// evaluates `goodbye`; if it returns a non-nil value, the bracketing source sends it to the sink.
    func bracketed(hello: @escaping () -> Value?, goodbye: @escaping () -> Value?) -> AnySource<Value> {
        return BracketingSource(self, hello: hello, goodbye: goodbye).anySource
    }
}

private final class BracketingSource<Input: SourceType>: _AbstractSource<Input.Value> {
    typealias Value = Input.Value
    let input: Input
    let hello: () -> Value?
    let goodbye: () -> Value?

    init(_ input: Input, hello: @escaping () -> Value?, goodbye: @escaping () -> Value?) {
        self.input = input
        self.hello = hello
        self.goodbye = goodbye
    }

    final override func add<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Value {
        // Note that this assumes issue #5 ("Disallow reentrant updates") is implemented.
        // Otherwise `sink.receive` could send values itself, which it also needs to receive,
        // requiring complicated scheduling.
        if let greeting = hello() {
            sink.receive(greeting)
        }
        return input.add(sink)
    }

    final override func remove<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Value {
        let last = input.remove(sink)
        if let farewell = goodbye() {
            sink.receive(farewell)
        }
        return last
    }
}
