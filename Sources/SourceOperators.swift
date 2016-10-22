//
//  SourceOperators.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

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


class TransformedSource<Input: SourceType, Value>: _AbstractSourceBase<Value> {
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
        return MappedSource(input: self, transform: transform).concealed
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
        return FilteredSource(input: self, filter: predicate).concealed
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
        return OptionalMappedSource(input: self, transform: transform).concealed
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
        return FlattenedSource(input: self, transform: transform).concealed
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
    public func dispatch(_ queue: DispatchQueue) -> AnySource<Value> {
        return DispatchOnQueueSource(input: self, queue: queue).concealed
    }
}

private final class DispatchOnQueueSource<Input: SourceType>: TransformedSource<Input, Input.Value> {
    typealias Value = Input.Value
    let queue: DispatchQueue

    init(input: Input, queue: DispatchQueue) {
        self.queue = queue
        super.init(input: input)
    }

    override func receive<Sink: SinkType>(_ value: Input.Value, for sink: Sink) where Sink.Value == Value {
        queue.async {
            sink.receive(value)
        }
    }
}

extension SourceType {
    public func dispatch(_ queue: OperationQueue) -> AnySource<Value> {
        return DispatchOnOperationQueueSource(input: self, queue: queue).concealed
    }
}

private final class DispatchOnOperationQueueSource<Input: SourceType>: TransformedSource<Input, Input.Value> {
    typealias Value = Input.Value
    let queue: OperationQueue

    init(input: Input, queue: OperationQueue) {
        self.queue = queue
        super.init(input: input)
    }

    override func receive<Sink: SinkType>(_ value: Input.Value, for sink: Sink) where Sink.Value == Value {
        if OperationQueue.current == queue {
            sink.receive(value)
        }
        else {
            queue.addOperation {
                sink.receive(value)
            }
        }
    }
}

extension SourceType {
    public func buffered() -> AnySource<Value> {
        return BufferedSource(self).concealed
    }
}

private final class BufferedSource<Input: SourceType>: _AbstractSourceBase<Input.Value>, SinkType {
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
