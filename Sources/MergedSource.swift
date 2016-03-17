//
//  MergedSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-04.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension SourceType {
    /// Returns a source that merges self with `source`. The returned source will forward all values sent by either
    /// of its two input sources to its own connected sinks.
    ///
    /// It is fine to chain multiple merges together: `MergedSource` has its own, specialized `merge` method to 
    /// collapse multiple merges into a single source.
    public func merge<S: SourceType where S.SourceValue == SourceValue>(source: S) -> MergedSource<SourceValue> {
        return MergedSource(sources: [self.source, source.source])
    }

    public static func merge(sources: Self...) -> MergedSource<SourceValue> {
        return MergedSource(sources: sources.map { s in s.source })
    }

    public static func merge<S: SequenceType where S.Generator.Element == Self>(sources: S) -> MergedSource<SourceValue> {
        return MergedSource(sources: sources.map { s in s.source })
    }
}

/// A Source that receives all values from a set of input sources and forwards all to its own connected sinks.
///
/// Note that MergedSource only connects to its input sources while it has at least one connection of its own.
public final class MergedSource<Value>: SourceType, SignalDelegate {
    public typealias SourceValue = Value

    private let inputs: [Source<Value>]

    private var signal = OwningSignal<Value, MergedSource<Value>>()

    private var mutex = RawMutex()
    private var connections: [Connection] = []

    /// Initializes a new merged source with `sources` as its input sources.
    public init<S: SequenceType where S.Generator.Element: SourceType, S.Generator.Element.SourceValue == Value>(sources: S) {
        self.inputs = sources.map { $0.source }
    }

    deinit {
        mutex.destroy()
    }

    public var connecter: Sink<Value> -> Connection {
        return signal.with(self).connecter
    }

    /// Returns a new MergedSource that merges the same sources as self but also listens to `source`.
    /// The returned source will forward all values sent by either of its input sources to its own connected sinks.
    public func merge<S: SourceType where S.SourceValue == Value>(source: S) -> MergedSource<Value> {
        return MergedSource(sources: self.inputs + [source.source])
    }

    internal func start(signal: Signal<Value>) {
        mutex.withLock {
            assert(connections.isEmpty)
            connections = inputs.map { $0.connect(signal) }
        }
    }

    internal func stop(signal: Signal<Value>) {
        mutex.withLock {
            for c in connections {
                c.disconnect()
            }
            connections.removeAll()
        }
    }
}
