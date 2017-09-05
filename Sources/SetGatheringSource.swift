//
//  SetGatheringSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2017-09-05.
//  Copyright © 2017 Károly Lőrentey. All rights reserved.
//

extension ObservableSetType where Element: SourceType {
    public func gather() -> AnySource<Element.Value> {
        return SetGatheringSource(self).anySource
    }
}

private class SetGatheringSource<Origin: ObservableSetType, Value>: _AbstractSource<Value>
where Origin.Element: SourceType, Origin.Element.Value == Value {
    let origin: Origin
    var sinks: Set<AnySink<Value>> = []

    private struct GatherSink: UniqueOwnedSink {
        typealias Owner = SetGatheringSource
        unowned let owner: Owner

        func receive(_ value: SetUpdate<Origin.Element>) {
            guard case let .change(change) = value else { return }
            change.removed.forEach { source in
                for sink in owner.sinks {
                    source.remove(sink)
                }
            }
            change.inserted.forEach { source in
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

