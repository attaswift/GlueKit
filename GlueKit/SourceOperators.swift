//
//  SourceOperators.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension SourceType {
    public func sourceOperator<Output>(operation: (Value, Output->Void)->Void) -> Source<Output> {
        return Source<Output> { sink in self.connect { value in operation(value, sink) } }
    }

    public func map<Output>(transform: Value->Output) -> Source<Output> {
        return sourceOperator { input, sink in
            sink(transform(input))
        }
    }

    public func filter(predicate: Value->Bool) -> Source<Value> {
        return sourceOperator { input, sink in
            if predicate(input) {
                sink(input)
            }
        }
    }

    public func flatMap<Output>(transform: Value->Output?) -> Source<Output> {
        return sourceOperator { input, sink in
            if let output = transform(input) {
                sink(output)
            }
        }
    }

    public func flatMap<Output>(transform: Value->[Output]) -> Source<Output> {
        return sourceOperator { input, sink in
            for output in transform(input) {
                sink(output)
            }
        }
    }

    public func dispatch(queue: dispatch_queue_t) -> Source<Value> {
        return sourceOperator { input, sink in
            dispatch_async(queue, { sink(input) })
        }
    }

    public func dispatch(queue: NSOperationQueue) -> Source<Value> {
        return sourceOperator { input, sink in
            if NSOperationQueue.currentQueue() == queue {
                sink(input)
            }
            else {
                queue.addOperationWithBlock { sink(input) }
            }
        }
    }

    public func everyNth(n: Int) -> Source<Value> {
        assert(n > 0)
        return Source { sink in
            var count = 0
            return self.connect { value in
                if ++count == n {
                    count = 0
                    sink(value)
                }
            }
        }
    }
}

extension SourceType {
    public static func latestOf<B: SourceType>(a: Self, _ b: B) -> UnionSource<(Value, B.Value)> {
        typealias A = Self
        typealias Result = (A.Value, B.Value)
        var lock = Spinlock()
        var av: A.Value? = nil
        var bv: B.Value? = nil

        let sa: Source<(A.Value, B.Value)> = a.flatMap { (value: A.Value) -> (A.Value, B.Value)? in
            return lock.locked {
                av = value
                if let bv = bv {
                    return (value, bv)
                }
                return nil
            }
        }
        let sb: Source<(A.Value, B.Value)> = b.flatMap { (value: B.Value) -> (A.Value, B.Value)? in
            return lock.locked {
                bv = value
                if let av = av {
                    return (av, value)
                }
                return nil
            }
        }
        return UnionSource([sa, sb])
    }
}

