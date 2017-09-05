//
//  MergedSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-04.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import SipHash

extension Sequence where Element: SourceType {
    public func gather() -> MergedSource<Element.Value> {
        return MergedSource(sources: self)
    }
}

extension SourceType {
    /// Returns a source that merges self with `source`. The returned source will forward all values sent by either
    /// of its two input sources to its own connected sinks.
    ///
    /// It is fine to chain multiple merges together: `MergedSource` has its own, specialized `merge` method to 
    /// collapse multiple merges into a single source.
    public func merged<S: SourceType>(with source: S) -> MergedSource<Value> where S.Value == Value {
        return MergedSource(sources: [self.anySource, source.anySource])
    }

    public static func merge(_ sources: Self...) -> MergedSource<Value> {
        return MergedSource(sources: sources.map { s in s.anySource })
    }

    public static func merge<S: Sequence>(_ sources: S) -> MergedSource<Value> where S.Iterator.Element == Self {
        return MergedSource(sources: sources.map { s in s.anySource })
    }
}

/// A Source that receives all values from a set of input sources and forwards all to its own connected sinks.
///
/// Note that MergedSource only connects to its input sources while it has at least one connection of its own.
public final class MergedSource<Value>: SignalerSource<Value> {
    public typealias SourceValue = Value

    private let inputs: [AnySource<Value>]

    /// Initializes a new merged source with `sources` as its input sources.
    public init<S: Sequence>(sources: S) where S.Iterator.Element: SourceType, S.Iterator.Element.Value == Value {
        self.inputs = sources.map { $0.anySource }
    }

    override func activate() {
        for i in 0 ..< inputs.count {
            inputs[i].add(MergedSink(source: self, index: i))
        }
    }

    override func deactivate() {
        for i in 0 ..< inputs.count {
            inputs[i].remove(MergedSink(source: self, index: i))
        }
    }

    fileprivate func receive(_ value: Value, from index: Int) {
        signal.send(value)
    }

    /// Returns a new MergedSource that merges the same sources as self but also listens to `source`.
    /// The returned source will forward all values sent by either of its input sources to its own connected sinks.
    public func merged<Source: SourceType>(with source: Source) -> MergedSource<Value> where Source.Value == Value {
        return MergedSource(sources: self.inputs + [source.anySource])
    }
}

private struct MergedSink<Value>: SinkType, SipHashable {
    let source: MergedSource<Value>
    let index: Int

    func receive(_ value: Value) {
        source.receive(value, from: index)
    }

    func appendHashes(to hasher: inout SipHasher) {
        hasher.append(ObjectIdentifier(source))
        hasher.append(index)
    }

    static func ==(left: MergedSink, right: MergedSink) -> Bool {
        return left.source === right.source && left.index == right.index
    }
}


