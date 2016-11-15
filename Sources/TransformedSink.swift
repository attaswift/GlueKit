//
//  TransformedSink.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-29.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import SipHash

public protocol SinkTransform: Hashable {
    associatedtype Input
    associatedtype Output

    func apply<Sink: SinkType>(_ input: Input, _ sink: Sink) where Sink.Value == Output
}

extension SinkTransform where Self: AnyObject {
    public var hashValue: Int { return ObjectIdentifier(self).hashValue }
    public static func ==(a: Self, b: Self) -> Bool { return a === b }
}

extension SinkType {
    func transform<Transform: SinkTransform>(_ transform: Transform) -> TransformedSink<Self, Transform> where Transform.Output == Value {
        return TransformedSink(sink: self, transform: transform)
    }
}

public struct TransformedSink<Sink: SinkType, Transform: SinkTransform>: SinkType, SipHashable where Transform.Output == Sink.Value {
    public let sink: Sink
    public let transform: Transform

    public func receive(_ value: Transform.Input) {
        transform.apply(value, sink)
    }

    public func appendHashes(to hasher: inout SipHasher) {
        hasher.append(sink)
        hasher.append(transform)
    }

    public static func ==(left: TransformedSink, right: TransformedSink) -> Bool {
        return left.sink == right.sink && left.transform == right.transform
    }
}

class SinkTransformFromClosure<I, O>: SinkTransform {
    typealias Input = I
    typealias Output = O

    let transform: (Input, (Output) -> Void) -> Void

    init(_ transform: @escaping (Input, (Output) -> Void) -> Void) {
        self.transform = transform
    }

    func apply<Sink: SinkType>(_ input: Input, _ sink: Sink) where Sink.Value == Output {
        transform(input, sink.receive)
    }
}

class SinkTransformFromMapping<I, O>: SinkTransform {
    typealias Input = I
    typealias Output = O

    let mapping: (Input) -> Output

    init(_ mapping: @escaping (Input) -> Output) {
        self.mapping = mapping
    }

    func apply<Sink: SinkType>(_ input: Input, _ sink: Sink) where Sink.Value == Output {
        sink.receive(mapping(input))
    }
}

class SinkTransformFromOptionalMapping<I, O>: SinkTransform {
    typealias Input = I
    typealias Output = O

    let mapping: (Input) -> Output?

    init(_ mapping: @escaping (Input) -> Output?) {
        self.mapping = mapping
    }

    func apply<Sink: SinkType>(_ input: Input, _ sink: Sink) where Sink.Value == Output {
        if let output = mapping(input) {
            sink.receive(output)
        }
    }
}

class SinkTransformFromFilter<I>: SinkTransform {
    typealias Input = I
    typealias Output = I

    let filter: (Input) -> Bool

    init(_ filter: @escaping (Input) -> Bool) {
        self.filter = filter
    }

    func apply<Sink: SinkType>(_ input: Input, _ sink: Sink) where Sink.Value == Output {
        if filter(input) {
            sink.receive(input)
        }
    }
}

class SinkTransformFromSequence<Input, S: Sequence>: SinkTransform {
    typealias Output = S.Iterator.Element

    let transform: (Input) -> S

    init(_ transform: @escaping (Input) -> S) {
        self.transform = transform
    }

    func apply<Sink: SinkType>(_ input: Input, _ sink: Sink) where Sink.Value == Output {
        for output in transform(input) {
            sink.receive(output)
        }
    }
}
