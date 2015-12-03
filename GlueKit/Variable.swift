//
//  Variable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A Variable holds a modifiable value and provides several kinds of sources to observe its changes.
/// It also provides a sink that sets the value of the variable.
///
/// Variable is thread-safe and reentrant; it is OK to update its value or connect to any of its sources at any time and from any thread. (As long as you ensure that reentrant updates will not lead to infinite update cycles.)
///
public final class Variable<Value>: SourceType, SinkType {
    public typealias Sink = Value -> Void

    private let equalityTest: (Value, Value) -> Bool
    private var _lock = Spinlock()
    private var _value: Value
    private weak var _signal: Signal<Value>? = nil // Created on demand, released immediately when unused

    /// Create a new variable with an initial value and equality test. The test is called after each update with the previous and new value of the variable; the sinks are executed iff the test returns false.
    /// @param value: The initial value of the variable.
    /// @param equalityTest: A closure that decides whether two values are to be considered equal. The test should be referentially transparent and fast.
    public init(_ value: Value, equalityTest: (Value, Value) -> Bool) {
        self.equalityTest = equalityTest
        self._value = value
    }

    /// Return the existing signal or create a new one if needed.
    private var signal: Signal<Value> {
        return _lock.locked {
            if let signal = _signal {
                return signal
            }
            else {
                let signal = Signal<Value>()
                _signal = signal
                return signal
            }
        }
    }

    /// The current value of the variable.
    public var value: Value {
        get { return _lock.locked { _value } }
        set { setValue(newValue) }
    }

    /// Update the value of this variable, and send the new value to all sinks that are currently connected. The sinks are only triggered if the value is not equal to the previous value, according to the equality test given in init.
    public func setValue(value: Value) {
        let signal = self.signal
        _lock.locked {
            let notify = !equalityTest(_value, value)
            _value = value
            if notify {
                signal.sendLater(value)
            }
        }
        signal.sendNow()
    }

    /// A read-only view of this variable.
    public var getter: Getter<Value> { return Getter(self) }

    /// A source that reports all future values of this variable. (The initial value of the variable at the time of a new connection is not sent to the new sink.)
    public var futureSource: Source<Value> { return self.signal.source }

    /// A sink that sets the value of this variable (triggering all sinks connected to it in turn).
    public var sink: Sink { return self.setValue }

    /// A source that immediately sends the value of this variable to new sinks that are connected to it, then sends updated values on future changes.
    public var source: Source<Value> {
        return Source<Value> { sink in
            // Sending the current value is tricky to get right without locking the variable for the duration of the initial sink call. The naive implementation below can report an outdated value if updates arrive between lines (1) and (2):
            //
            //     1) let connection = signal.connect(sink)
            //     2) sink(self.value)
            //     3) return connection
            //
            // Swapping the two lines can lead to skipped values, which is slightly better, but not great.
            // 
            // The implementation below remembers values sent while it was sending the initial value, then repeats them. This prevents reentrant invocations of the sink, like Signal does.

            let signal = self.signal

            var sinkLock = Spinlock()
            var pendingValues: [Value]? = []

            let shouldSendImmediately: Value->Bool = { value in
                if pendingValues == nil {
                    return true
                }
                else {
                    pendingValues!.append(value)
                    return false
                }
            }
            let nextValue: Void->Value? = {
                if pendingValues!.isEmpty {
                    pendingValues = nil // Allow future values to be sent immediately
                    return nil
                }
                else {
                    return pendingValues!.removeFirst()
                }
            }

            // Atomically connect the sink and enqueue the current value.
            let connection: Connection = self._lock.locked {
                pendingValues = [self._value]
                return signal.source.connect { value in
                    if sinkLock.locked({ shouldSendImmediately(value) }) {
                        sink(value)
                    }
                }
            }

            // Run the sink on the queue.
            while let value: Value = sinkLock.locked(nextValue) {
                sink(value)
            }
            return connection
        }
    }
}

extension Variable where Value: Equatable {
    /// Create a new variable with an initial value. Use the == operator as the equality test.
    /// @param value: The initial value of the variable.
    public convenience init(_ value: Value) {
        self.init(value, equalityTest: ==)
    }
}

extension Variable {

    /// Create a two-way binding from self to a slave variable. The slave is updated to the current value of self. 
    /// All future updates will be synchronized between the two variables until the returned connection is disconnected.
    /// To prevent infinite cycles, at least one of the variables must have a non-pathologic equality test.
    @warn_unused_result(message = "You probably want to keep the connection alive by retaining it")
    public func bind(slave: Variable<Value>) -> Connection {
        let connection = self.connect(slave)
        let c = slave.futureSource.connect(self)
        connection.addCallback { id in c.disconnect() }
        return connection
    }
}

/// A read-only view of a Variable. You can get the current value and connect sinks to a Getter, but you cannot modify its value.
public struct Getter<Value>: SourceType {
    private let variable: Variable<Value>

    private init(_ variable: Variable<Value>) {
        self.variable = variable
    }

    /// The current value of the variable.
    public var value: Value { return variable.value }

    /// A source providing the current value and values of future updates of this variable.
    public var source: Source<Value> { return variable.source }

    /// A source providing values of future updates to this variable.
    public var futureSource: Source<Value>  { return variable.futureSource }
}

