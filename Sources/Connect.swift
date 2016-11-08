//
//  Connect.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-22.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension SourceType {
    /// Connect `sink` to this source. The sink will receive all values that this source produces in the future.
    /// The connection will be kept active until the returned connection object is deallocated or explicitly disconnected.
    ///
    /// In GlueKit, a connection holds strong references to both its source and sink; thus sources (and sinks) are kept
    /// alive at least as long as they have an active connection.
    public func connect(_ sink: @escaping (Value) -> Void) -> Connection {
        return ConcreteConnection(source: self, sink: sink)
    }
}

/// An object that controls the lifetime of a closure's subscription to a source.
///
/// The closure's subscription to the source remains active until this object is deallocated
/// or `disconnect` is called on it.
public class Connection {
    internal init() {}
    public func disconnect() { abstract() }
}

/// An object that controls the lifetime of a closure's subscription to a particular source.
internal class ConcreteConnection<Source: SourceType>: Connection {
    typealias Value = Source.Value

    var source: Source?
    var sink: Optional<(Value) -> Void>

    init(source: Source, sink: @escaping (Value) -> Void) {
        self.source = source
        self.sink = sink
        super.init()

        // Wrap the closure in a sink and add it to the source.
        source.add(ClosureSink(ObjectIdentifier(self), sink))
    }

    deinit {
        disconnect()
    }

    public override func disconnect() {
        guard let source = self.source, let sink = self.sink else { return }

        // Construct a dummy `ClosureSink` that looks identical to the original one and remove it from the source.
        // At first glance, we could use a dummy closure here, because the closure isn't involved in the sink's identity.
        // However, sources sometimes synchronously send farewell values to removed sinks using the instance 
        // given here --- so using e.g. an empty closure would lose these.
        source.remove(ClosureSink(ObjectIdentifier(self), sink))

        // Release resources associated with this connection.
        self.source = nil
        self.sink = nil
    }
}

private struct ClosureSinkData<Value> {
    /// The connection of this sink, serving as the unique identifier of it.
    unowned let connection: Connection
}

/// A Sink that wraps a closure. `Hashable` is implemented by using the identity of the unique `Connection`
/// object associated with the subscription.
internal struct ClosureSink<Value>: SinkType {
    /// The object identifier of connection object.
    /// The natural choice would be to use an unowned reference to the connection object itself;
    /// but `Connection`'s `deinit` needs to be able to create `ClosureSink`s, and it's not a good 
    /// idea to create unowned references during deinit -- the semantics are unclear to me, and I get crashes.
    private let identifier: ObjectIdentifier

    /// The closure that is to be called when this sink receives a value.
    private let sink: (Value) -> Void

    init(_ identifier: ObjectIdentifier, _ sink: @escaping (Value) -> Void) {
        self.identifier = identifier
        self.sink = sink
    }

    func receive(_ value: Value) {
        sink(value)
    }

    var hashValue: Int {
        return identifier.hashValue
    }

    static func ==(left: ClosureSink, right: ClosureSink) -> Bool {
        // Sink equality is based on the identity of the connection.
        return left.identifier == right.identifier
    }
}

extension Connector {
    @discardableResult
    public func connect<Source: SourceType>(_ source: Source, to sink: @escaping (Source.Value) -> Void) -> Connection {
        return source.connect(sink).putInto(self)
    }
}
