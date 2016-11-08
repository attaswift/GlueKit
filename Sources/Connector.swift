//
//  Connector.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

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
}
