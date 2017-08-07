//
//  Sink.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-22.
//  Copyright © 2015–2017 Károly Lőrentey.
//

public protocol SinkType: Hashable {
    associatedtype Value
    func receive(_ value: Value)

    var anySink: AnySink<Value> { get }
}

extension SinkType {
    public var anySink: AnySink<Value> {
        return AnySink(SinkBox<Self>(self))
    }
}

extension SinkType where Self: AnyObject {
    public func unowned() -> AnySink<Value> {
        return UnownedSink(self).anySink
    }
    public var hashValue: Int { return ObjectIdentifier(self).hashValue }
    public static func ==(a: Self, b: Self) -> Bool { return a === b }
}

public struct AnySink<Value>: SinkType {
    // TODO: Replace this with a generalized protocol existential when Swift starts supporting those.
    // (We always need to allocate a box for the sink, while an existential may have magical inline storage for 
    // tiny sinks -- say, less than three words.)

    private let box: _AbstractSink<Value>

    fileprivate init(_ box: _AbstractSink<Value>) {
        self.box = box
    }

    public func receive(_ value: Value) {
        box.receive(value)
    }

    public var anySink: AnySink<Value> {
        return self
    }

    public var hashValue: Int {
        return box.hashValue
    }

    public static func ==(left: AnySink, right: AnySink) -> Bool {
        return left.box == right.box
    }

    public func opened<Sink: SinkType>(as type: Sink.Type = Sink.self) -> Sink? where Sink.Value == Value {
        if let sink = self as? Sink { return sink }
        if let sink = box as? Sink { return sink }
        if let box = self.box as? SinkBox<Sink> { return box.contents }
        return nil
    }
}

fileprivate class _AbstractSink<Value>: SinkType {
    // TODO: Eliminate this when Swift starts supporting generalized protocol existentials.

    func receive(_ value: Value) { abstract() }

    var hashValue: Int { abstract() }

    func isEqual(to other: _AbstractSink<Value>) -> Bool { abstract() }

    public static func ==(left: _AbstractSink<Value>, right: _AbstractSink<Value>) -> Bool {
        return left.isEqual(to: right)
    }

    public final var anySink: AnySink<Value> {
        return AnySink(self)
    }
}

fileprivate class SinkBox<Wrapped: SinkType>: _AbstractSink<Wrapped.Value> {
    // TODO: Eliminate this when Swift starts supporting generalized protocol existentials.

    typealias Value = Wrapped.Value

    fileprivate let contents: Wrapped

    init(_ contents: Wrapped) {
        self.contents = contents
    }

    override func receive(_ value: Value) {
        contents.receive(value)
    }

    override var hashValue: Int {
        return contents.hashValue
    }

    override func isEqual(to other: _AbstractSink<Wrapped.Value>) -> Bool {
        guard let other = other as? SinkBox<Wrapped> else { return false }
        return self.contents == other.contents
    }
}

fileprivate class UnownedSink<Wrapped: SinkType & AnyObject>: _AbstractSink<Wrapped.Value> {
    typealias Value = Wrapped.Value

    unowned let wrapped: Wrapped

    init(_ wrapped: Wrapped) {
        self.wrapped = wrapped
    }

    override func receive(_ value: Value) {
        wrapped.receive(value)
    }

    override var hashValue: Int {
        return wrapped.hashValue
    }

    override func isEqual(to other: _AbstractSink<Wrapped.Value>) -> Bool {
        guard let other = other as? UnownedSink<Wrapped> else { return false }
        return self.wrapped == other.wrapped
    }
}
