//
//  Source.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A Source is a entity that is able to produce values to other entities (called Sinks) that are connected to it. A source can be an observable value (see Variable<Value>), a KVO-compatible key path on an object (see NSObject.sourceForKeyPath), a notification (see NSNotificationCenter.sourceForName), a timer (see TimedSource), etc. etc.
///
/// We represent a source by a struct holding the subscription closure; this allows extensions on it, which is convenient. GlueKit provides built-in extension methods for transforming sources to other kinds of sources.
///
/// A source is intended to be equivalent to a read-only propery. Therefore, while a source typically has a mechanism for sending values, this is intentionally outside the scope of this construct (see Signal<Value>).
public struct Source<Value>: SourceProvider {
    public typealias Sink = Value -> Void

    private let connecter: Sink -> Connection

    public init(_ connecter: Sink -> Connection) {
        self.connecter = connecter
    }

    public init<Provider: SourceProvider where Provider.Value == Value>(_ sourceProvider: Provider) {
        self.connecter = sourceProvider.source.connecter
    }

    public var source: Source<Value> { return self }
}

/// A SourceProvider is anything that provides a Source. This protocol is used as a convenient extension point.
public protocol SourceProvider {
    typealias Value

    /// The source provided by this entity.
    var source: Source<Value> { get }
}

/// A SinkProvider is anything that provides a Sink. This protocol is used as a convenient extension point.
public protocol SinkProvider {
    typealias Value

    /// The sink provided by this entity.
    var sink: Value->Void { get }
}

extension SourceProvider {
    public typealias Sink = Value -> Void

    /// Connect `sink` to the source provided by this entity. The sink will receive all values that this source produces in the future.
    /// The connection will be kept active until the returned connection object is deallocated or explicitly disconnected.
    @warn_unused_result
    public func connect(sink: Sink) -> Connection {
        return source.connecter(sink)
    }

    /// Connect the sink provided by `sinkProvider` to the source provided by this entity. The sink will receive all values that this source produces in the future.
    /// The connection will be kept active until the returned connection object is deallocated or explicitly disconnected.
    @warn_unused_result
    public func connect<P: SinkProvider where P.Value == Value>(sinkProvider: P) -> Connection {
        return source.connect(sinkProvider.sink)
    }
}
