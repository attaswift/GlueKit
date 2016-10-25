//
//  BufferedSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-25.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension SourceType {
    public func buffered() -> AnySource<Value> {
        return BufferedSource(self).anySource
    }
}

private final class BufferedSource<Input: SourceType>: _AbstractSource<Input.Value>, SinkType {
    typealias Value = Input.Value

    private let _source: Input
    private let _signal = Signal<Value>()

    init(_ source: Input) {
        self._source = source
        super.init()
    }

    final override func add<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Value {
        let first = _signal.add(sink)
        if first {
            _source.add(self)
        }
        return first
    }

    final override func remove<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Value {
        let last = _signal.remove(sink)
        if last {
            _source.remove(self)
        }
        return last
    }

    func receive(_ value: Input.Value) {
        _signal.send(value)
    }
}
