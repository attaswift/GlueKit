//
//  Signal.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// Holds a strong reference to a value that may not be ready for consumption yet.
private enum Ripening<Value> {
    case Ripe(Value)
    case Unripe(Value)

    var ripeValue: Value? {
        if case Ripe(let value) = self  {
            return value
        }
        else {
            return nil
        }
    }

    mutating func ripen() {
        if case Unripe(let value) = self {
            self = Ripe(value)
        }
    }
}

private enum PendingItem<Value> {
    case SendValue(Value)
    case RipenSinkWithID(ConnectionID)
}


/// A Signal is a source that has an exposed method to send a value to all sinks that are currently connected to it.
///
/// The Five Rules of Signal:
/// 0. Signal only sends values to sinks that it receives via Signal.send(). All such values are forwarded to sinks connected at the time of the send (if any).
/// 1. Sends are serialized. Signal defines a strict order between the values sent to it, forming a single sequence of values.
/// 2. All sinks get the same values. Each sink receives a subsequence of the Signal's value sequence. No reordering, no skipping, no duplicates.
/// 3. Connections are serialized with sends. Each sink's value subsequence starts with the first value that was (started to be) sent after it was connected (if any).
/// 4. Disconnection is immediate. No new value is sent to a sink after its connection has finished disconnecting.
///
/// Some implementation notes:
///
/// The simplest nontrivial way to implement these rules is to make the Signal synchronous by serializing send() using a lock -- this
/// is the way chosen by ReactiveCocoa and RxSwift. This makes reentrant send() calls deadlock, but that's probably a good thing.
/// (You can emulate reentrant sends by scheduling an asyncronous send; however, that can visibly break value ordering.)
///
/// As an experiment, this particular Signal implementation allows send() to be called from any thread at any time -- including reentrant
/// send()s from a sink that is currently being executed by it. To ensure the rule set above, reentrant and concurrent sends and connects
/// are asynchronous. They are ordered in a queue and performed at the end of the active send that first entered the signal.
///
/// For reference, KVO's analogue to Signal in Foundation supports reentrancy, but its send() is synchronous. There is no way to satisy
/// the Signal rules in a system like that. KVO's designers chose to resolve this by always calling observers with the latest value of 
/// the observed key path. That's a nice pragmatic solution in the face of reentrancy, but it only makes sense when you have the concept
/// of a current value, which Signal doesn't. (Although Variable does.)
///
public final class Signal<Value>: SourceType, SinkType {
    public typealias Sink = Value->Void

    private var lock = NSLock()
    private var sending = false
    private var sinks: Dictionary<ConnectionID, Ripening<Sink>> = [:]
    private var pendingItems: [PendingItem<Value>] = []

    /// A closure that is run whenever this signal transitions from an empty signal to one having a single connection. (Executed on the thread that connects the first sink.)
    internal let didConnectFirstSink: Void->Void

    /// A closure that is run whenever this signal transitions from having at least one connection to having no connections. (Executed on the thread that disconnects the last sink.)
    internal let didDisconnectLastSink: Void->Void

    /// @param didConnectFirstSink: A closure that is run whenever this signal transitions from an empty signal to one having a single connection. (Executed on the thread that connects the first sink.)
    /// @param didDisconnectLastSink: A closure that is run whenever this signal transitions from having at least one connection to having no connections. (Executed on the thread that disconnects the last sink.)
    internal init(didConnectFirstSink: Void->Void, didDisconnectLastSink: Void->Void) {
        self.didConnectFirstSink = didConnectFirstSink
        self.didDisconnectLastSink = didDisconnectLastSink
    }

    public convenience init() {
        self.init(didConnectFirstSink: {}, didDisconnectLastSink: {})
    }

    /// The source of this Signal.
    public var source: Source<Value> { return Source(self._connect) }
    /// A sink that, when executed, triggers the source of this Signal.
    public var sink: Sink { return self.send }

    /// Returns true if the signal is free for sending. Enters the sending state if so.
    /// When the signal is already in the sending state, this function appends the value to the pending list, and returns false.
    private func _shouldSendNowAndIfSoThenEnterSendingState(value: Value) -> Bool {
        return lock.locked {
            if self.sinks.isEmpty {
                // Shortcut: If there are no sinks, value can be discarded immediately.
                return false
            }
            else if self.sending {
                // We are already sending some values; remember this send for later.
                self.pendingItems.append(.SendValue(value))
                return false
            }
            else {
                // Send the value immediately.
                self.sending = true
                return true
            }
        }
    }

    /// Return the pending value that needs to be sent next, or nil. Exit the sending state when there are no more values.
    private func _nextValueToSendOrElseLeaveSendingState() -> Value? {
        return lock.locked {
            assert(self.sending)
            while case .Some(let item) = self.pendingItems.first {
                self.pendingItems.removeFirst()
                switch item {
                case .SendValue(let value):
                    if !self.sinks.isEmpty { // Skip value if there are no sinks.
                        // Send the next value to all ripe sinks.
                        return value
                    }
                case .RipenSinkWithID(let id):
                    self.sinks[id]?.ripen()
                }
            }
            // There are no more items to process.
            self.sending = false
            return nil
        }
    }

    /// Synchronously send a value to all connected sinks.
    private func _sendValueNow(value: Value) {
        assert(sending)

        // Note that sinks are allowed to freely add or remove connections. This loop is constructed to support this correctly:
        // - New sinks added while we are sending a value will not fire.
        // - Sinks removed during the iteration will not fire.
        for (id, _) in lock.locked({ return self.sinks }) {
            if let sink = lock.locked({ return self.sinks[id]?.ripeValue }) {
                sink(value)
            }
        }
    }

    /// Send a value to all sinks currently connected to this Signal. The sinks are executed in undefined order.
    ///
    /// The sinks are normally executed synchronously. However, when two or more threads are sending values at the same time, or when a connected sink sends a value back to this same signal, then only the send() arriving first is synchronous; the rest are performed asynchronously on the thread of the first send(), before the first send() returns.
    ///
    /// You may safely call this method from any thread, provided that the sinks are OK with running there.
    public func send(value: Value) {
        if _shouldSendNowAndIfSoThenEnterSendingState(value) {
            _sendValueNow(value)
            while let value = _nextValueToSendOrElseLeaveSendingState() {
                _sendValueNow(value)
            }
        }
    }

    private func _connect(sink: Sink) -> Connection {
        let c = Connection(callback: self.disconnect) // c now holds a strong reference to self.
        let id = c.connectionID
        let first: Bool = lock.locked {
            let first = self.sinks.isEmpty
            if self.sending {
                // Values that are currently pending should not be sent to this sink, but any future values should be.
                self.sinks[id] = .Unripe(sink)
                self.pendingItems.append(.RipenSinkWithID(id))
            }
            else {
                self.sinks[id] = .Ripe(sink)
            }
            return first
        }

        // c is holding us, and we now hold a strong reference to the sink, so c holds both us and the sink.

        if first {
            self.didConnectFirstSink()
        }
        return c
    }

    private func disconnect(id: ConnectionID) {
        let last = lock.locked { ()->Bool in
            return self.sinks.removeValueForKey(id) != nil && self.sinks.isEmpty
        }
        if last {
            self.didDisconnectLastSink()
        }
    }
}
