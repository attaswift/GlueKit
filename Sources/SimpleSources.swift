//
//  SimpleSources.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension SourceType {
    /// Returns a source that never fires.
    public static func empty() -> AnySource<Value> {
        return NeverSource<Value>().anySource
    }

    /// Returns a source that never fires.
    public static func never() -> AnySource<Value> {
        return NeverSource<Value>().anySource
    }
}

class NeverSource<Value>: _AbstractSource<Value> {
    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        // Do nothing.
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
        // Do nothing.
        return sink
    }
}

extension SourceType {
    /// Returns a source that fires exactly once with the given value, then never again.
    public static func just(_ value: Value) -> AnySource<Value> {
        return JustSource(value).anySource
    }
}

class JustSource<Value>: _AbstractSource<Value> {
    private var value: Value

    init(_ value: Value) {
        self.value = value
        super.init()
    }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        sink.receive(value)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
        return sink
    }
}
