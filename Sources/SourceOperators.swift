//
//  SourceOperators.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension SourceType {
    public func sourceOperator<Output>(_ operation: (SourceValue, Sink<Output>) -> Void) -> Source<Output> {
        return Source<Output> { sink in self.connect { value in operation(value, sink) } }
    }

    public func map<Output>(_ transform: (SourceValue) -> Output) -> Source<Output> {
        return sourceOperator { input, sink in
            sink.receive(transform(input))
        }
    }

    public func filter(_ predicate: (SourceValue) -> Bool) -> Source<SourceValue> {
        return sourceOperator { input, sink in
            if predicate(input) {
                sink.receive(input)
            }
        }
    }

    public func flatMap<Output>(_ transform: (SourceValue) -> Output?) -> Source<Output> {
        return sourceOperator { input, sink in
            if let output = transform(input) {
                sink.receive(output)
            }
        }
    }

    public func flatMap<Output>(_ transform: (SourceValue) -> [Output]) -> Source<Output> {
        return sourceOperator { input, sink in
            for output in transform(input) {
                sink.receive(output)
            }
        }
    }

    public func dispatch(_ queue: DispatchQueue) -> Source<SourceValue> {
        return sourceOperator { input, sink in
            queue.async(execute: { sink.receive(input) })
        }
    }

    public func dispatch(_ queue: OperationQueue) -> Source<SourceValue> {
        return sourceOperator { input, sink in
            if OperationQueue.current == queue {
                sink.receive(input)
            }
            else {
                queue.addOperation { sink.receive(input) }
            }
        }
    }

    public func everyNth(_ n: Int) -> Source<SourceValue> {
        assert(n > 0)
        return Source { sink in
            var count = 0
            return self.connect { value in
                count += 1
                if count == n {
                    count = 0
                    sink.receive(value)
                }
            }
        }
    }
}

extension SourceType {
    public static func latestOf<B: SourceType>(_ a: Self, _ b: B) -> MergedSource<(SourceValue, B.SourceValue)> {
        typealias A = Self
        typealias Result = (A.SourceValue, B.SourceValue)
        let mutex = Mutex()
        var av: A.SourceValue? = nil
        var bv: B.SourceValue? = nil

        let sa: Source<(A.SourceValue, B.SourceValue)> = a.flatMap { (value: A.SourceValue) -> (A.SourceValue, B.SourceValue)? in
            return mutex.withLock {
                av = value
                if let bv = bv {
                    return (value, bv)
                }
                return nil
            }
        }
        let sb: Source<(A.SourceValue, B.SourceValue)> = b.flatMap { (value: B.SourceValue) -> (A.SourceValue, B.SourceValue)? in
            return mutex.withLock {
                bv = value
                if let av = av {
                    return (av, value)
                }
                return nil
            }
        }
        return MergedSource(sources: [sa, sb])
    }
}
