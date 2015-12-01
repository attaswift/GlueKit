//
//  Signal.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A Signal is a source that has an exposed method to send a value to all sinks that are currently connected to it.
public final class Signal<Value>: SourceProvider, SinkProvider {
    public typealias Sink = Value->Void

    private var lock = Spinlock()
    private var sinks: Dictionary<ConnectionID, Sink> = [:]

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

    /// Send a value to all sinks currently connected to this Signal. The sinks are executed synchronously, in unspecified order.
    ///
    /// You may safely call this method from any thread, provided that the sinks are OK with running there.
    public func send(value: Value) {
        // Note that sinks are allowed to freely add or remove connections. This loop is constructed to support this correctly:
        // - New sinks added during iteration will not fire.
        // - Sinks removed during the iteration will not fire (unless the loop has already fired them before they were removed).
        for (id, _) in lock.locked({ return self.sinks }) {
            if let sink = lock.locked({ return self.sinks[id] }) {
                sink(value)
            }
        }
    }

    private func _connect(sink: Sink) -> Connection {
        let c = Connection(callback: self.disconnect) // c now holds a strong reference to self

        let id = c.connectionID
        let first = lock.locked { () -> Bool in
            let first = self.sinks.isEmpty
            self.sinks[id] = sink
            return first
        }
        // We now hold a strong reference to the sink.

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
