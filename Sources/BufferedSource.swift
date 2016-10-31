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

private final class BufferedSource<Input: SourceType>: SignalerSource<Input.Value>, SinkType {
    typealias Value = Input.Value

    private let source: Input

    init(_ source: Input) {
        self.source = source
        super.init()
    }

    override func activate() {
        source.add(self.unowned())
    }

    override func deactivate() {
        source.remove(self.unowned())
    }

    func receive(_ value: Input.Value) {
        signal.send(value)
    }
}
