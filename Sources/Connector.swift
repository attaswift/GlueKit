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
        disconnect()
    }


    private func add(connection: Connection) {
        let id = connection.connectionID
        assert(connections[id] == nil)
        connections[id] = connection
        connection.addCallback { [weak self] id in self?.connections.removeValueForKey(id) }
    }

    public func disconnect() {
        let cs = connections
        connections.removeAll()
        for (_, c) in cs {
            c.disconnect()
        }
    }

    public func connect<Source: SourceType>(source: Source, to sink: Source.SourceValue->Void) -> Connection {
        return source.connect(sink).putInto(self)
    }

    public func connect<Source: SourceType, Target: SinkType where Source.SourceValue == Target.SinkValue>(source: Source, to sink: Target) -> Connection {
        return source.connect(sink).putInto(self)
    }

    public func connect<Source: ObservableType>(source: Source, to sink: Source.Value->Void) -> Connection {
        return source.values.connect(sink).putInto(self)
    }

    public func connect<Source: ObservableType, Target: SinkType where Source.Value == Target.SinkValue>(source: Source, to sink: Target) -> Connection {
        return source.values.connect(sink).putInto(self)
    }

    public func bind<Source: UpdatableType, Target: UpdatableType where Source.Value == Target.Value>(source: Source, to target: Target, withEqualityTest equalityTest: (Source.Value, Source.Value) -> Bool) {
        source.bind(target, equalityTest: equalityTest).putInto(self)
    }

    public func bind<Value: Equatable, Source: UpdatableType, Target: UpdatableType where Source.Value == Value, Target.Value == Value>(source: Source, to target: Target) {
        source.bind(target).putInto(self)
    }
}

extension Connection {
    /// Put this connection into `connector`. The connector will disconnect the connection when it is deallocated.
    public func putInto(connector: Connector) -> Connection {
        connector.add(self)
        return self
    }
}
