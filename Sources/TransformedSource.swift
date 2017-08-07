//
//  TransformedSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015–2017 Károly Lőrentey.
//

final class TransformedSource<Input: SourceType, Transform: SinkTransform>: _AbstractSource<Transform.Output> where Transform.Input == Input.Value {
    let input: Input
    let transform: Transform

    init(input: Input, transform: Transform) {
        self.input = input
        self.transform = transform
    }

    final override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Transform.Output {
        self.input.add(sink.transform(transform))
    }

    @discardableResult
    final override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Transform.Output {
        return self.input.remove(sink.transform(transform)).sink
    }
}

extension SourceType {
    /// Returns a source that, applies `transform` on each value produced by `self` and each subscriber sink.
    ///
    /// `transform` should be a pure function, i.e., one with no side effects or hidden parameters.
    /// For each value that is received from `self`, it is called as many times as there are subscribers.
    public func transform<Result>(_ type: Result.Type = Result.self, _ transform: @escaping (Value, (Result) -> Void) -> Void) -> AnySource<Result> {
        return TransformedSource(input: self, transform: SinkTransformFromClosure(transform)).anySource
    }

    public func map<Output>(_ transform: @escaping (Value) -> Output) -> AnySource<Output> {
        return TransformedSource(input: self, transform: SinkTransformFromMapping(transform)).anySource
    }

    public func flatMap<Output>(_ transform: @escaping (Value) -> Output?) -> AnySource<Output> {
        return TransformedSource(input: self, transform: SinkTransformFromOptionalMapping(transform)).anySource
    }

    public func filter(_ predicate: @escaping (Value) -> Bool) -> AnySource<Value> {
        return TransformedSource(input: self, transform: SinkTransformFromFilter(predicate)).anySource
    }

    public func flatMap<S: Sequence>(_ transform: @escaping (Value) -> S) -> AnySource<S.Iterator.Element> {
        return TransformedSource(input: self, transform: SinkTransformFromSequence(transform)).anySource
    }

    public func mapToVoid() -> AnySource<Void> {
        return TransformedSource(input: self, transform: SinkTransformToConstant(())).anySource
    }

    public func mapToConstant<C>(_ value: C) -> AnySource<C> {
        return TransformedSource(input: self, transform: SinkTransformToConstant(value)).anySource
    }
}
