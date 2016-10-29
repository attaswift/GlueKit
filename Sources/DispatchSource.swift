//
//  DispatchSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-24.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension SourceType {
    public func dispatch(on queue: DispatchQueue) -> AnySource<Value> {
        return TransformedSource(input: self, transform: SinkTransformForDispatchQueue(queue)).anySource
    }

    public func dispatch(on queue: OperationQueue) -> AnySource<Value> {
        return TransformedSource(input: self, transform: SinkTransformForOperationQueue(queue)).anySource
    }
}

final class SinkTransformForDispatchQueue<Value>: SinkTransform {
    typealias Input = Value
    typealias Output = Value

    let queue: DispatchQueue

    init(_ queue: DispatchQueue) {
        self.queue = queue
    }

    func apply<Sink: SinkType>(_ input: Value, _ sink: Sink) where Sink.Value == Value {
        queue.async {
            sink.receive(input)
        }
    }
}

final class SinkTransformForOperationQueue<Value>: SinkTransform {
    typealias Input = Value
    typealias Output = Value

    let queue: OperationQueue

    init(_ queue: OperationQueue) {
        self.queue = queue
    }

    func apply<Sink: SinkType>(_ input: Value, _ sink: Sink) where Sink.Value == Value {
        if OperationQueue.current == queue {
            sink.receive(input)
        }
        else {
            queue.addOperation {
                sink.receive(input)
            }
        }
    }
}
