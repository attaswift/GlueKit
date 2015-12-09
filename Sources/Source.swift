//
//  Source.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

//MARK: Sink

/// A Sink is anything that can receive a value, typically from a Source.
///
/// Sinks implement the SinkType protocol. It only has a single method, `receive`.
///
/// SinkType is a protocol with an associated value, which can be sometimes inconvenient to work with.
/// GlueKit provides the struct `Sink<Value>` to represent a type-lifted sink.
/// In most places that accept sinks, you can also simply use raw closures that take a single argument.
///
/// - SeeAlso: Sink<Value>, SourceType, Source<Value>
public protocol SinkType {
    /// The type of values received by this sink.
    typealias SinkValue

    /// Receive a new value.
    func receive(value: SinkValue)
}

/// A Sink is anything that can receive a value, typically from a Source.
///
/// `Sink<Value>` represents a type-lifted sink. You can use the `SourceType.sink` property (defined in an extension)
/// to convert any `SourceType` into a `Sink<Value>`.
///
/// - SeeAlso: SinkType
///
public struct Sink<Value>: SinkType {
    public typealias SinkValue = Value

    private let receiver: Value->Void

    /// Initialize a new `Sink<Value>` from the given closure.
    public init(_ receiver: Value->Void) {
        self.receiver = receiver
    }

    /// Initializes a new `Sink<Value>` from the given value implementing `SinkType`.
    public init<S: SinkType where S.SinkValue == Value>(_ sink: S) {
        self.receiver = sink.receive
    }

    /// Receive a new value.
    public func receive(value: SinkValue) {
        self.receiver(value)
    }
}

extension SinkType {
    /// Returns a type-lifted representation of this sink.
    public var sink: Sink<SinkValue> { return Sink(self) }
}

//MARK: Source

/// A Source is an entity that is able to produce values to other entities (called Sinks) that are connected to it. 
/// A source can be an observable value (see Variable<Value>), a KVO-compatible key path on an object 
/// (see NSObject.sourceForKeyPath), a notification (see NSNotificationCenter.sourceForNotification), 
/// a timer (see TimerSource), etc. etc.
///
/// Sources implement the `SourceType` protocol. It only has a single method, `connect`; it can be used to subscribe
/// new sinks to values produced by this source.
///
/// `SourceType` is a protocol with an associated value, which can be sometimes inconvenient to work with. 
/// GlueKit provides the struct `Source<Value>` to represent a type-lifted source.
///
/// A source is intended to be equivalent to a read-only propery. Therefore, while a source typically has a mechanism
/// for sending values, this is intentionally outside the scope of `SourceType`. (But see `Signal<Value>`).
///
/// We represent a source by a struct holding the subscription closure; this allows extensions on it, which is convenient. 
/// GlueKit provides built-in extension methods for transforming sources to other kinds of sources.
///
public protocol SourceType {
    /// The type of values produced by this source.
    typealias SourceValue

    /// Connect `sink` to this source. The sink will receive all values that this source produces in the future.
    /// The connection will be kept active until the returned connection object is deallocated or explicitly disconnected.
    ///
    /// In GlueKit, a connection holds strong references to both its source and sink; thus sources (and sinks) are kept
    /// alive at least as long as they have an active connection.
    @warn_unused_result(message = "You probably want to keep the connection alive by retaining it")
    func connect(sink: Sink<SourceValue>) -> Connection
}

/// A Source is an entity that is able to produce values to other entities (called Sinks) that are connected to it.
/// A source can be an observable value (see Variable<Value>), a KVO-compatible key path on an object
/// (see NSObject.sourceForKeyPath), a notification (see NSNotificationCenter.sourceForNotification),
/// a timer (see TimerSource), etc. etc.
///
/// Sources implement the `SourceType` protocol. It only has a single method, `connect`; it can be used to subscribe
/// new sinks to values produced by this source.
///
/// `SourceType` is a protocol with an associated value, which is sometimes inconvenient to work with. GlueKit
/// provides the struct `Source<Value>` to represent a type-lifted source.
///
/// A source is intended to be equivalent to a read-only propery. Therefore, while a source typically has a mechanism
/// for sending values, this is intentionally outside the scope of `SourceType`. (But see `Signal<Value>`).
///
/// We represent a source by a struct holding the subscription closure; this allows extensions on it, which is convenient.
/// GlueKit provides built-in extension methods for transforming sources to other kinds of sources.
///
public struct Source<Value>: SourceType {
    public typealias SourceValue = Value

    private let connecter: Sink<Value> -> Connection

    public init(_ connecter: Sink<Value> -> Connection) {
        self.connecter = connecter
    }

    public init<S: SourceType where S.SourceValue == Value>(_ source: S) {
        self.connecter = source.connect
    }

    @warn_unused_result(message = "You probably want to keep the connection alive by retaining it")
    public func connect(sink: Sink<Value>) -> Connection {
        return source.connecter(sink)
    }

    public var source: Source<Value> { return self }
}

extension SourceType {
    /// Returns a type-lifted representation of this source.
    public var source: Source<SourceValue> { return Source(self) }

    /// Connect `sink` to this source. The sink will receive all values that this source produces in the future.
    /// The connection will be kept active until the returned connection object is deallocated or explicitly disconnected.
    ///
    /// In GlueKit, a connection holds strong references to both its source and sink; thus sources (and sinks) are kept
    /// alive at least as long as they have an active connection.
    @warn_unused_result(message = "You probably want to keep the connection alive by retaining it")
    public func connect(sink: SourceValue->Void) -> Connection {
        return connect(Sink(sink))
    }

    /// Connect `sink` to this source. The sink will receive all values that this source produces in the future.
    /// The connection will be kept active until the returned connection object is deallocated or explicitly disconnected.
    ///
    /// In GlueKit, a connection holds strong references to both its source and sink; thus sources (and sinks) are kept
    /// alive at least as long as they have an active connection.
    @warn_unused_result(message = "You probably want to keep the connection alive by retaining it")
    public func connect<S: SinkType where S.SinkValue == SourceValue>(sink: S) -> Connection {
        return source.connect(sink.sink)
    }
}
