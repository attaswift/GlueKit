//
//  Source.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015–2017 Károly Lőrentey.
//

/// A Source is an entity that is able to produce values to other entities (called Sinks) that are connected to it.
/// A source can be an observable value (see Variable<Value>), a KVO-compatible key path on an object 
/// (see NSObject.sourceForKeyPath), a notification (see NSNotificationCenter.sourceForNotification), 
/// a timer (see TimerSource), etc. etc.
///
/// Sources implement the `SourceType` protocol. It only has a single method, `subscribe`; it can be used to subscribe
/// new sinks to values produced by this source.
///
/// `SourceType` is a protocol with an associated value, which can be sometimes inconvenient to work with. 
/// GlueKit provides the struct `Source<Value>` to represent a type-erased source.
///
/// A source is intended to be equivalent to a read-only propery. Therefore, while a source typically has a mechanism
/// for sending values, this is intentionally outside the scope of `SourceType`. (But see `Signal<Value>`).
///
/// We represent a source by a struct holding the subscription closure; this allows extensions on it, which is convenient. 
/// GlueKit provides built-in extension methods for transforming sources to other kinds of sources.
///
public protocol SourceType {
    /// The type of values produced by this source.
    associatedtype Value

    /// Subscribe `sink` to this source, i.e., retain the sink and start calling its `receive` function 
    /// whenever this source produces a value. 
    /// The subscription remains active until `remove` is called with an identical sink.
    ///
    /// - SeeAlso: `subscribe`, `remove`
    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value

    /// Remove `sink`'s subscription to this source, i.e., stop calling the sink's `receive` function and release it.
    /// The subscription remains active until `remove` is called with an identical sink.
    ///
    /// - Returns: The sink that was previously added to the sink. 
    ///     This may be distinguishable by the input parameter by identity comparison or some other means.
    /// - SeeAlso: `subscribe`, `add`
    @discardableResult
    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value

    /// A type-erased representation of this source.
    var anySource: AnySource<Value> { get }
}


extension SourceType {
    public var anySource: AnySource<Value> {
        return AnySource(box: SourceBox(self))
    }
}

/// A Source is an entity that is able to produce values to other entities (called Sinks) that are connected to it.
/// A source can be an observable value (see Variable<Value>), a KVO-compatible key path on an object
/// (see NSObject.sourceForKeyPath), a notification (see NSNotificationCenter.sourceForNotification),
/// a timer (see TimerSource), etc. etc.
///
/// Sources implement the `SourceType` protocol. It only has a single method, `subscribe`; it can be used to subscribe
/// new sinks to values produced by this source.
///
/// `SourceType` is a protocol with an associated value, which is sometimes inconvenient to work with. GlueKit
/// provides the struct `Source<Value>` to represent a type-erased source.
///
/// A source is intended to be equivalent to a read-only propery. Therefore, while a source typically has a mechanism
/// for sending values, this is intentionally outside the scope of `SourceType`. (But see `Signal<Value>`).
///
/// We represent a source by a struct holding the subscription closure; this allows extensions on it, which is convenient.
/// GlueKit provides built-in extension methods for transforming sources to other kinds of sources.
///
public struct AnySource<Value>: SourceType {
    private let box: _AbstractSource<Value>

    internal init(box: _AbstractSource<Value>) {
        self.box = box
    }

    public func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        box.add(sink)
    }

    @discardableResult
    public func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
        return box.remove(sink)
    }

    public var anySource: AnySource<Value> { return self }
}

open class _AbstractSource<Value>: SourceType {
    open func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value { abstract() }

    @discardableResult
    open func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value { abstract() }

    public final var anySource: AnySource<Value> {
        return AnySource(box: self)
    }
}

open class SignalerSource<Value>: _AbstractSource<Value>, SignalDelegate {
    internal lazy var signal: Signal<Value> = .init(delegate: self)

    public final override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        self.signal.add(sink)
    }

    @discardableResult
    public final override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
        return self.signal.remove(sink)
    }

    func activate() {}
    func deactivate() {}
}

internal class SourceBox<Base: SourceType>: _AbstractSource<Base.Value> {
    typealias Value = Base.Value

    let base: Base

    init(_ base: Base) {
        self.base = base
    }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        base.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
        return base.remove(sink)
    }
}
