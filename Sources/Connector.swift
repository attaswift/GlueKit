//
//  Connector.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A class for controlling the lifecycle of connections.
/// The connector owns a set of connections and forces them to disconnect when it is deallocated.
public class Connector {
    private var connections = [ConnectionID: Connection]()

    public init() {}

    deinit {
        for (_, c) in connections {
            c.disconnect()
        }
    }

    public func connect<S: SourceType>(source: S, sink: S.Value->Void) -> Connection {
        let c = source.connect(sink)
        add(c)
        return c
    }

    private func add(connection: Connection) {
        let id = connection.connectionID
        assert(connections[id] == nil)
        connections[id] = connection
        connection.addCallback { [weak self] id in self?.connections.removeValueForKey(id) }
    }
}

extension Connection {
    public func putInto(connector: Connector) -> Connection {
        connector.add(self)
        return self
    }
}
