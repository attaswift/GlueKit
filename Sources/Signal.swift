//
//  Signal.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015–2017 Károly Lőrentey.
//

internal protocol SignalDelegate: class {
    func activate()
    func deactivate()
}

extension SignalDelegate {
    func activate() {}
    func deactivate() {}
}

private enum PendingItem<Value> {
    case sendValue(Value)
    case addSink(AnySink<Value>)
}

/// A Signal is both a source and a sink. Sending a value to a signal's sink forwards it to all sinks that are 
/// currently connected to the signal. The signal's sink is named "send", and it is available as a direct method.
///
/// The Five Rules of Signal:
///
/// 0. Signal only sends values to sinks that it receives via Signal.send(). All such values are forwarded to 
///    sinks connected at the time of the send (if any).
/// 1. Sends are serialized. Signal defines a strict order between the values sent to it, forming a single 
///    sequence of values.
/// 2. All sinks get the same values. Each sink receives a subsequence of the Signal's value sequence. No reordering,
///    no skipping, no duplicates.
/// 3. Connections are serialized with sends. Each sink's value subsequence starts with the first value that 
///    was (started to be) sent after it was connected (if any).
/// 4. Disconnection is immediate. No new value is sent to a sink after its connection has finished disconnecting.
///
/// Some implementation notes:
///
/// The simplest nontrivial way to implement these rules is to make the Signal synchronous by serializing send() 
/// using a lock -- this is the way chosen by ReactiveCocoa and RxSwift. This makes reentrant send() calls deadlock, 
/// but that's probably a good thing. (You can emulate reentrant sends by scheduling an asyncronous send; however,
/// that can visibly break value ordering.)
///
/// As an experiment, this particular Signal implementation allows send() to be called from any thread at any 
/// time---including reentrant send()s from a sink that is currently being executed by it. To ensure the rule set
/// above, reentrant and concurrent sends and connects are asynchronous. They are ordered in a queue and performed 
/// at the end of the active send that first entered the signal. This implementation never invokes sinks recursively 
/// inside another sink invocation.
///
/// For reference, KVO's analogue to Signal in Foundation supports reentrancy, but its send() is synchronous. There 
/// is no way to satisfy the above rules in a system like that. KVO's designers chose to resolve this by always calling 
/// observers with the latest value of the observed key path. That's a nice pragmatic solution in the face of 
/// reentrancy, but it only makes sense when you have the concept of a current value, which Signal doesn't. 
/// (Although Variable does.)
///
public class Signal<Value>: _AbstractSource<Value> {
    internal weak var delegate: SignalDelegate?
    private let lock = Lock()
    private var sending = false
    private var sinks: Set<AnySink<Value>> = []
    private var pendingItems: [PendingItem<Value>] = []

    public override init() {
        self.delegate = nil
        super.init()
    }

    internal init(delegate: SignalDelegate) {
        self.delegate = delegate
        super.init()
    }

    deinit {
        precondition(sinks.count == 0 && pendingItems.count == 0)
    }

    /// Atomically return the pending value that needs to be sent next, or nil.
    /// If there are no more values, exit the sending state.
    private func _nextValueToSend(enterSending: Bool) -> Value? {
        return lock.withLock {
            if enterSending {
                if self.sending { return nil }
                self.sending = true
            }
            else {
                assert(self.sending)
            }
            while case .some(let item) = self.pendingItems.first {
                self.pendingItems.removeFirst()
                switch item {
                case .sendValue(let value):
                    if !self.sinks.isEmpty { // Skip value if there are no sinks.
                        // Send the next value to all ripe sinks.
                        return value
                    }
                case .addSink(let sink):
                    let (inserted, _) = self.sinks.insert(sink)
                    precondition(inserted, "Sink is already subscribed to this signal")
                }
            }
            // There are no more items to process.
            self.sending = false
            return nil
        }
    }

    /// Synchronously send a value to all connected sinks.
    private func _sendValueNow(_ value: Value) {
        assert(lock.withLock { sending })

        // Note that sinks are allowed to freely add or remove connections. 
        // This loop is constructed to support this correctly:
        // - New sinks added while we are sending a value will not fire.
        // - Sinks removed during the iteration will not fire.
        for sink in lock.withLock({ self.sinks }) {
            if lock.withLock({ self.sinks.contains(sink) }) {
                sink.receive(value)
            }
        }
    }

    /// Send a value to all sinks currently connected to this Signal. The sinks are executed in undefined order.
    ///
    /// The sinks are normally executed synchronously. However, when two or more threads are sending values at the 
    /// same time, or when a connected sink sends a value back to this same signal, then only the send() arriving 
    /// first is synchronous; the rest are performed asynchronously on the thread of the first send(), before the 
    /// first send() returns.
    ///
    /// You may safely call this method from any thread, provided that the sinks are OK with running there.
    public func send(_ value: Value) {
        let path: Bool? = lock.withLock {
            if sending {
                self.pendingItems.append(.sendValue(value))
                return nil // Value has been scheduled; somebody else will send it.
            }
            sending = true
            if self.pendingItems.isEmpty {
                return true
            }
            self.pendingItems.append(.sendValue(value))
            return false
        }
        if let fast = path {
            if fast {
                // Fast track: We can send the value immediately.
                _sendValueNow(value)
            }
            // Send remaining pending items in order.
            while let v = _nextValueToSend(enterSending: false) {
                _sendValueNow(v)
            }
        }
    }

    /// Append value to the queue of pending values. The value will be sent by a send() or sendNow() invocation.
    /// (If sendNow() is already running (recursively up the call stack, or on another thread), then the value will be
    /// sent by that invocation. If not, the first upcoming send will send the value.)
    ///
    /// Calls to sendLater() should always be followed by at least one call to sendNow().
    ///
    /// This construct is useful to control the ordering of notifications about changes to a value in the face of 
    /// concurrent modifications, without calling send() inside a lock. For example, here is a thread-safe, reentrant 
    /// counter that guarantees to send increasing counts, without holding a lock during sending:
    ///
    /// ```
    /// public struct Counter {
    ///     private let mutex = Mutex()
    ///     private var count: Int = 0
    ///     private let signal = Signal<Int>()
    ///
    ///     public var source: Source<Int> { return signal.source }
    ///
    ///     public mutating func increment() {
    ///         let value: Int = mutex.withLock {
    ///             let v = ++count
    ///             signal.sendLater(v)
    ///             return v
    ///         }
    ///         signal.sendNow()
    ///         return value
    ///     }
    /// }
    /// ```
    internal func sendLater(_ value: Value) {
        lock.withLock {
            self.pendingItems.append(.sendValue(value))
        }
    }

    /// Send all pending values immediately, or do nothing if the signal is already sending values elsewhere.
    /// (On another thread, or if this is a recursive call of sendNow on the current thread.)
    internal func sendNow() {
        if let value = _nextValueToSend(enterSending: true) {
            _sendValueNow(value)
            while let value = _nextValueToSend(enterSending: false) {
                _sendValueNow(value)
            }
        }
    }

    public override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        let sink = sink.anySink
        let first: Bool = lock.withLock {
            let first = self.sinks.isEmpty
            if self.pendingItems.isEmpty {
                let (inserted, _) = self.sinks.insert(sink)
                precondition(inserted, "Sink is already subscribed to this signal")
            }
            else {
                // Values that are currently pending should not be sent to this sink, but any future values should be.
                self.pendingItems.append(.addSink(sink))
            }
            return first
        }
        if first {
            delegate?.activate()
        }
    }

    @discardableResult
    public override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
        let sink = sink.anySink
        let (last, old): (Bool, AnySink<Value>) = lock.withLock {
            var old = self.sinks.remove(sink)
            if old == nil {
                for i in 0 ..< pendingItems.count {
                    if case .addSink(let s) = pendingItems[i], s == sink {
                        old = s
                        pendingItems.remove(at: i)
                        break
                    }
                }
            }
            precondition(old != nil, "Sink is not subscribed to this signal")
            return (self.sinks.isEmpty, old!)
        }
        if last {
            delegate?.deactivate()
        }
        return old.opened()!
    }

    public var isConnected: Bool {
        return lock.withLock { !self.sinks.isEmpty }
    }
}

extension Signal {
    public var asSink: AnySink<Value> { return SignalSink(self).anySink }
}

extension Signal where Value == Void {
    public func send() {
        self.send(())
    }
}

private struct SignalSink<Value>: SinkType {
    private let signal: Signal<Value>

    init(_ signal: Signal<Value>) {
        self.signal = signal
    }

    func receive(_ value: Value) {
        signal.send(value)
    }

    var hashValue: Int {
        return ObjectIdentifier(signal).hashValue
    }

    static func ==(left: SignalSink, right: SignalSink) -> Bool {
        return left.signal === right.signal
    }
}
