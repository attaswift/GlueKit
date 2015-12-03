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
///
public struct Source<Value>: SourceType {
    public typealias Sink = Value -> Void

    private let connecter: Sink -> Connection

    public init(_ connecter: Sink -> Connection) {
        self.connecter = connecter
    }

    public init<S: SourceType where S.Value == Value>(_ source: S) {
        self.connecter = source.source.connecter
    }

    public var source: Source<Value> { return self }
}

/// A SourceType is anything that provides a Source. This protocol is used as a convenient extension point.
public protocol SourceType {
    typealias Value

    /// The source provided by this entity.
    var source: Source<Value> { get }
}

/// A SinkType is anything that provides a Sink. This protocol is used as a convenient extension point.
public protocol SinkType {
    typealias Value

    /// The sink provided by this entity.
    var sink: Value->Void { get }
}

// Connect methods.
extension SourceType {
    public typealias Sink = Value -> Void

    /// Connect `sink` to the source provided by this entity. The sink will receive all values that this source produces in the future.
    /// The connection will be kept active until the returned connection object is deallocated or explicitly disconnected.
    ///
    /// Note that a connection holds strong references to both its source and sink; thus sources (and sinks) are kept alive as long as they have an active connection.
    @warn_unused_result(message = "You probably want to keep the connection alive by storing it somewhere")
    public func connect(sink: Sink) -> Connection {
        return source.connecter(sink)
    }

    /// Connect the sink provided by `SinkType` to the source provided by this entity. The sink will receive all values that this source produces in the future.
    /// The connection will be kept active until the returned connection object is deallocated or explicitly disconnected.
    ///
    /// Note that a connection holds strong references to both its source and sink; thus sources (and sinks) are kept alive as long as they have an active connection.
    @warn_unused_result(message = "You probably want to keep the connection alive by storing it somewhere")
    public func connect<S: SinkType where S.Value == Value>(sink: S) -> Connection {
        return source.connect(sink.sink)
    }
}
