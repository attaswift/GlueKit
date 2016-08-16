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


    fileprivate func add(_ connection: Connection) {
        let id = connection.connectionID
        assert(connections[id] == nil)
        connections[id] = connection
        connection.addCallback { [weak self] id in _ = self?.connections.removeValue(forKey: id) }
    }

    public func disconnect() {
        let cs = connections
        connections.removeAll()
        for (_, c) in cs {
            c.disconnect()
        }
    }

    @discardableResult
    public func connect<Source: SourceType>(_ source: Source, to sink: @escaping (Source.SourceValue) -> Void) -> Connection {
        return source.connect(sink).putInto(self)
    }

    @discardableResult
    public func connect<Source: SourceType, Target: SinkType>(_ source: Source, to sink: Target) -> Connection where Source.SourceValue == Target.SinkValue {
        return source.connect(sink).putInto(self)
    }

    @discardableResult
    public func connect<Source: ObservableType>(_ source: Source, to sink: @escaping (Source.Value) -> Void) -> Connection {
        return source.values.connect(sink).putInto(self)
    }

    @discardableResult
    public func connect<Source: ObservableType, Target: SinkType>(_ source: Source, to sink: Target) -> Connection where Source.Value == Target.SinkValue {
        return source.values.connect(sink).putInto(self)
    }

    public func bind<Source: UpdatableType, Target: UpdatableType>(_ source: Source, to target: Target, withEqualityTest equalityTest: @escaping (Source.Value, Source.Value) -> Bool) where Source.Value == Target.Value {
        source.bind(target, equalityTest: equalityTest).putInto(self)
    }

    public func bind<Value: Equatable, Source: UpdatableType, Target: UpdatableType>(_ source: Source, to target: Target) where Source.Value == Value, Target.Value == Value {
        source.bind(target).putInto(self)
    }
}

extension Connection {
    /// Put this connection into `connector`. The connector will disconnect the connection when it is deallocated.
    @discardableResult
    public func putInto(_ connector: Connector) -> Connection {
        connector.add(self)
        return self
    }
}
