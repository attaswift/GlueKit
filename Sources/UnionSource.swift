//
//  UnionSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-04.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension SourceType {
    public func union<S: SourceType where S.SourceValue == SourceValue>(source: S) -> UnionSource<SourceValue> {
        return UnionSource([self.source, source.source])
    }

    public static func union(sources: Self...) -> UnionSource<SourceValue> {
        return UnionSource(sources.map { s in s.source })
    }

    public static func union<S: SequenceType where S.Generator.Element == Self>(sources: S) -> UnionSource<SourceValue> {
        return UnionSource(sources)
    }
}

public struct UnionSource<Value>: SourceType {
    public typealias SourceValue = Value

    private var lock = Spinlock()
    private var union: RealUnionSource<Value>

    public init(_ sources: [Source<Value>]) {
        self.union = RealUnionSource(sources.map { $0.source })
    }

    public init<Seq: SequenceType, Src: SourceType where Seq.Generator.Element == Src, Src.SourceValue == Value>(_ sources: Seq) {
        self.init(sources.map { $0.source })
    }

    public init<S: SourceType where S.SourceValue == Value>(sources: S...) {
        self.init(sources.map { $0.source })
    }
    
    public var source: Source<Value> { return union.source }

    private mutating func makeUnique() {
        if !isUniquelyReferencedNonObjC(&union) {
            lock.locked { union = union.copy() }
        }
    }

    public func union<S: SourceType where S.SourceValue == Value>(source: S) -> UnionSource<Value> {
        var result = self
        result.addSource(source)
        return result
    }

    private mutating func addSource<S: SourceType where S.SourceValue == Value>(source: S) {
        makeUnique()
        union.addSource(source)
    }
}

private class RealUnionSource<Value>: SourceType, SignalOwner {
    typealias SourceValue = Value

    private weak var _signal: Signal<Value>? = nil

    private var lock = Spinlock()

    private var connected = false
    private var sources: [Source<Value>]
    private var connections: [Connection]

    init(_ sources: [Source<Value>]) {
        self.sources = sources
        self.connections = []
    }

    private var signal: Signal<Value> {
        if let signal = _signal {
            return signal
        }
        else {
            let signal = Signal<Value>(stronglyHeldOwner: self)
            _signal = signal
            return signal
        }
    }

    var source: Source<Value> { return signal.source }

    func addSource<S: SourceType where S.SourceValue == Value>(source: S) {
        lock.locked {
            sources.append(source.source)
            if connected {
                connections.append(source.connect(self.signal))
            }
        }
        // Sources aren't comparable, so removing a source isn't supported.
    }

    private func copy() -> RealUnionSource<Value> {
        return lock.locked { RealUnionSource(self.sources) }
    }

    func signalDidStart(signal: Signal<Value>) {
        lock.locked {
            assert(!connected)
            assert(connections.isEmpty)
            connections = sources.map { $0.connect(signal) }
            connected = true
        }
    }

    func signalDidStop(signal: Signal<Value>) {
        lock.locked {
            assert(connected)
            for c in connections {
                c.disconnect()
            }
            connections.removeAll()
            connected = false
        }
    }
}
