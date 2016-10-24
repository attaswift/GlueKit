//
//  DispatchSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-24.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension SourceType {
    public func dispatch(_ queue: DispatchQueue) -> AnySource<Value> {
        return DispatchOnQueueSource(input: self, queue: queue).anySource
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
        return DispatchOnOperationQueueSource(input: self, queue: queue).anySource
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
