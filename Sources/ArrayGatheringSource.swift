//
//  ArrayGatheringSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2017-09-05.
//  Copyright © 2017 Károly Lőrentey. All rights reserved.
//

extension ObservableArrayType where Element: SourceType {
    public func gather() -> AnySource<Element.Value> {
        return ArrayGatheringSource(self).anySource
    }
}

private class ArrayGatheringSource<Origin: ObservableArrayType, Value>: _AbstractSource<Value>
where Origin.Element: SourceType, Origin.Element.Value == Value {
    let origin: Origin
    var sinks: Set<AnySink<Value>> = []

    private struct GatherSink: UniqueOwnedSink {
        typealias Owner = ArrayGatheringSource
        unowned let owner: Owner

        func receive(_ value: ArrayUpdate<Origin.Element>) {
            guard case let .change(change) = value else { return }
            change.forEachOld { source in
                for sink in owner.sinks {
                    source.remove(sink)
                }
            }
            change.forEachNew { source in
                for sink in owner.sinks {
                    source.add(sink)
                }
            }
        }
    }

    init(_ origin: Origin) {
        self.origin = origin
    }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        if sinks.isEmpty {
            origin.add(GatherSink(owner: self))
        }
        let new = sinks.insert(sink.anySink).inserted
        precondition(new)
        for source in origin.value {
            source.add(sink)
        }
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
        let result = sinks.remove(sink.anySink)!
        for source in origin.value {
            source.remove(result)
        }
        if sinks.isEmpty {
            origin.remove(GatherSink(owner: self))
        }
        return result.opened()!
    }
}

