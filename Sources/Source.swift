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
    associatedtype SinkValue

    /// Receive a new value.
    func receive(_ value: SinkValue) -> Void

    /// Returns a type-lifted representation of this sink.
    var sink: Sink<SinkValue> { get }
}

extension SinkType {
    public var sink: Sink<SinkValue> { return Sink(self) }
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

    private let _receiver: (Value) -> Void

    /// Initialize a new `Sink<Value>` from the given closure.
    public init(_ receiver: @escaping (Value) -> Void) {
        self._receiver = receiver
    }

    /// Initializes a new `Sink<Value>` from the given value implementing `SinkType`.
    public init<S: SinkType>(_ sink: S) where S.SinkValue == Value {
        self._receiver = sink.receive
    }

    public func receive(_ value: SinkValue) -> Void {
        self._receiver(value)
    }

    public var sink: Sink<SinkValue> { return self }
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
    associatedtype SourceValue

    /// Connect `sink` to this source. The sink will receive all values that this source produces in the future.
    /// The connection will be kept active until the returned connection object is deallocated or explicitly disconnected.
    ///
    /// In GlueKit, a connection holds strong references to both its source and sink; thus sources (and sinks) are kept
    /// alive at least as long as they have an active connection.
    func connect(_ sink: Sink<SourceValue>) -> Connection

    /// A type-lifted representation of this source.
    var source: Source<SourceValue> { get }
}

extension SourceType {
    /// A type-lifted representation of this source.
    public var source: Source<SourceValue> { return Source(self) }

    /// Connect `sink` to this source. The sink will receive all values that this source produces in the future.
    /// The connection will be kept active until the returned connection object is deallocated or explicitly disconnected.
    ///
    /// In GlueKit, a connection holds strong references to both its source and sink; thus sources (and sinks) are kept
    /// alive at least as long as they have an active connection.
    public func connect<S: SinkType>(_ sink: S) -> Connection where S.SinkValue == SourceValue {
        return self.connect(sink.sink)
    }

    /// Connect `sink` to this source. The sink will receive all values that this source produces in the future.
    /// The connection will be kept active until the returned connection object is deallocated or explicitly disconnected.
    ///
    /// In GlueKit, a connection holds strong references to both its source and sink; thus sources (and sinks) are kept
    /// alive at least as long as they have an active connection.
    public func connect(_ sink: @escaping (SourceValue) -> Void) -> Connection {
        return self.connect(Sink(sink))
    }
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

    private let _connecter: (Sink<Value>) -> Connection

    public init(_ connecter: @escaping (Sink<Value>) -> Connection) {
        self._connecter = connecter
    }

    public init<S: SourceType>(_ source: S) where S.SourceValue == Value {
        self._connecter = source.connect
    }

    public func connect(_ sink: Sink<Value>) -> Connection {
        return self._connecter(sink)
    }

    public var source: Source<Value> { return self }
}
