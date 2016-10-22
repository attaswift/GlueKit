//
//  Sink.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-22.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

public protocol SinkType: Hashable {
    associatedtype Value
    func receive(_ value: Value)

    var concealed: AnySink<Value> { get }
}

extension SinkType {
    public var concealed: AnySink<Value> {
        return AnySink(SinkBox(self))
    }
}

extension SinkType where Self: AnyObject {
    public var hashValue: Int { return ObjectIdentifier(self).hashValue }
    public static func ==(a: Self, b: Self) -> Bool { return a === b }
}

public struct AnySink<Value>: SinkType {
    // TODO: Replace this with a generalized protocol existential when Swift starts supporting those.
    // (We always need to allocate a box for the sink, while an existential may have magical inline storage for 
    // tiny sinks -- say, less than three words.)

    private let box: _AbstractSinkBase<Value>

    fileprivate init(_ box: _AbstractSinkBase<Value>) {
        self.box = box
    }

    public func receive(_ value: Value) {
        box.receive(value)
    }

    public var concealed: AnySink<Value> {
        return self
    }

    public var hashValue: Int {
        return box.hashValue
    }

    public static func ==(left: AnySink, right: AnySink) -> Bool {
        return left.box == right.box
    }
}

fileprivate class _AbstractSinkBase<Value>: SinkType {
    // TODO: Eliminate this when Swift starts supporting generalized protocol existentials.

    func receive(_ value: Value) {
        abstract()
    }

    var hashValue: Int {
        abstract()
    }

    func isEqual(to other: _AbstractSinkBase<Value>) -> Bool {
        abstract()
    }

    public static func ==(left: _AbstractSinkBase<Value>, right: _AbstractSinkBase<Value>) -> Bool {
        return left.isEqual(to: right)
    }

    public final var concealed: AnySink<Value> {
        return AnySink(self)
    }
}

fileprivate class SinkBox<Wrapped: SinkType>: _AbstractSinkBase<Wrapped.Value> {
    // TODO: Eliminate this when Swift starts supporting generalized protocol existentials.

    typealias Value = Wrapped.Value

    private let contents: Wrapped

    init(_ contents: Wrapped) {
        self.contents = contents
    }

    override func receive(_ value: Value) {
        contents.receive(value)
    }

    override var hashValue: Int {
        return contents.hashValue
    }

    override func isEqual(to other: _AbstractSinkBase<Wrapped.Value>) -> Bool {
        guard let other = other as? SinkBox<Wrapped> else { return false }
        return self.contents == other.contents
    }
}
