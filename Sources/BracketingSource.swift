//
//  BracketingSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-25.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension SourceType {
    /// Returns a version of this source that optionally prefixes or suffixes all observers' received values
    /// with computed start/end values.
    ///
    /// For each new subscriber, the returned source evaluates `hello`; if it returns a non-nil value,
    /// the value is sent to the sink; then the sink is added to `self`.
    ///
    /// For each subscriber that is to be removed, the returned source first removes it from `self`, then
    /// evaluates `goodbye`; if it returns a non-nil value, the bracketing source sends it to the sink.
    public func bracketed(hello: @escaping () -> Value?, goodbye: @escaping () -> Value?) -> AnySource<Value> {
        return BracketingSource(self, hello: hello, goodbye: goodbye).anySource
    }
}

private class BracketingSink<Sink: SinkType>: SinkType {
    typealias Value = Sink.Value

    let sink: Sink
    var pendingValues: [Value]?
    var removed = false

    init(_ sink: Sink) {
        self.sink = sink
        self.pendingValues = nil
    }

    init(_ sink: Sink, _ initial: Value) {
        self.sink = sink
        self.pendingValues = [initial]
    }

    func receive(_ value: Value) {
        if pendingValues == nil {
            sink.receive(value)
        }
        else {
            pendingValues!.append(value)
        }
    }

    var hashValue: Int { return sink.hashValue }
    static func ==(left: BracketingSink, right: BracketingSink) -> Bool {
        return left.sink == right.sink
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

    final override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        if let greeting = hello() {
            let bracketing = BracketingSink(sink, greeting)
            input.add(bracketing)
            while !bracketing.pendingValues!.isEmpty && !bracketing.removed {
                let value = bracketing.pendingValues!.removeFirst()
                bracketing.sink.receive(value)
            }
            bracketing.pendingValues = nil
        }
        else {
            input.add(BracketingSink(sink))
        }
    }

    @discardableResult
    final override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
        let old = input.remove(BracketingSink(sink))
        old.removed = true
        if let farewell = goodbye() {
            old.sink.receive(farewell)
        }
        return old.sink
    }
}
