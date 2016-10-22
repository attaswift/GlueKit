//
//  Connector.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension Connection {
    /// Put this connection into `connector`. The connector will disconnect the connection when it is deallocated.
    @discardableResult
    public func putInto(_ connector: Connector) -> Connection {
        connector.add(self)
        return self
    }
}

/// A class for controlling the lifecycle of connections.
/// The connector owns a set of connections and forces them to disconnect when it is deallocated.
public class Connector {
    private var connections: [Connection] = []

    public init() {}

    deinit {
        disconnect()
    }

    fileprivate func add(_ connection: Connection) {
        connections.append(connection)
    }

    public func disconnect() {
        let cs = connections
        connections.removeAll()
        for c in cs {
            c.disconnect()
        }
    }

    @discardableResult
    public func connect<Source: SourceType>(_ source: Source, to sink: @escaping (Source.Value) -> Void) -> Connection {
        return source.connect(sink).putInto(self)
    }

    #if false
    @discardableResult
    public func connect<Observable: ObservableType>(_ observable: Observable, to sink: @escaping (Observable.Change) -> Void) -> Connection {
        return observable.changes.connect(sink).putInto(self)
    }

    @discardableResult
    public func connect<Observable: ObservableType, Target: SinkType>(_ observable: Observable, to sink: Target) -> Connection
    where Observable.Change == Target.SinkValue {
        return observable.changes.connect(sink).putInto(self)
    }
    #endif
}
