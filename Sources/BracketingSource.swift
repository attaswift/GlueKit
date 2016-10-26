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
        // Note that this assumes issue #5 ("Disallow reentrant updates") is implemented.
        // Otherwise `sink.receive` could send values itself, which it also needs to receive,
        // requiring complicated scheduling.
        if let greeting = hello() {
            sink.receive(greeting)
        }
        input.add(sink)
    }

    final override func remove<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        input.remove(sink)
        if let farewell = goodbye() {
            sink.receive(farewell)
        }
    }
}
