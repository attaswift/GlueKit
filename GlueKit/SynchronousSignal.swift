//
//  SynchronousSignal.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-03.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A simple Signal that sends values synchronously. It uses a lock, so it does not allow reentrant sends.
/// You can use this if you can prove that sinks will never call send.
internal class SynchronousSignal<Value>: SignalType {
    typealias Sink = Value->Void

    private var lock = Spinlock()
    private let sendLock = NSLock(name: "com.github.lorentey.GlueKit.SynchronousSignal")
    private var sinks: Dictionary<ConnectionID, Sink> = [:]

    /// A closure that is run whenever this signal transitions from an empty signal to one having a single connection. (Executed on the thread that connects the first sink.)
    internal let didConnectFirstSink: SynchronousSignal<Value>->Void

    /// A closure that is run whenever this signal transitions from having at least one connection to having no connections. (Executed on the thread that disconnects the last sink.)
    internal let didDisconnectLastSink: SynchronousSignal<Value>->Void

    /// @param didConnectFirstSink: A closure that is run whenever this signal transitions from an empty signal to one having a single connection. (Executed on the thread that connects the first sink.)
    /// @param didDisconnectLastSink: A closure that is run whenever this signal transitions from having at least one connection to having no connections. (Executed on the thread that disconnects the last sink.)
    internal init(didConnectFirstSink: SynchronousSignal<Value>->Void, didDisconnectLastSink: SynchronousSignal<Value>->Void) {
        self.didConnectFirstSink = didConnectFirstSink
        self.didDisconnectLastSink = didDisconnectLastSink
    }

    internal convenience init<Owner: SignalOwner where Owner.Signal == SynchronousSignal<Value>>(owner: Owner) {
        self.init(
            didConnectFirstSink: { [unowned owner] signal in owner.signalDidStart(signal) },
            didDisconnectLastSink: { [unowned owner] signal in owner.signalDidStop(signal) })
    }

    internal convenience init() {
        self.init(didConnectFirstSink: { s in }, didDisconnectLastSink: { s in })
    }

    internal var source: Source<Value> { return Source(self.connect) }
    internal var sink: Sink { return self.send }

    internal func send(value: Value) {
        sendLock.locked {
            for (id, _) in lock.locked({ sinks }) {
                if let sink = lock.locked({ sinks[id] }) {
                    sink(value)
                }
            }
        }
    }

    private func disconnect(id: ConnectionID) {
        let last: Bool = lock.locked {
            self.sinks.removeValueForKey(id)
            return self.sinks.isEmpty
        }
        if last {
            self.didDisconnectLastSink(self)
        }
    }

    internal func connect(sink: Sink) -> Connection {
        let c = Connection(callback: self.disconnect)
        let id = c.connectionID
        let first: Bool = lock.locked {
            self.sinks[id] = sink
            return self.sinks.count == 1
        }
        // c is holding self via its callback, and we now hold a strong reference to the sink, so c holds both self and the sink.
        if first {
            self.didConnectFirstSink(self)
        }
        return c        
    }
}
