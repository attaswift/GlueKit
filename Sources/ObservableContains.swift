//
//  ObservableContains.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-02.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableSetType where Change == SetChange<Element> {
    public func observableContains(_ member: Element) -> AnyObservableValue<Bool> {
        return ObservableContains(input: self, member: member).anyObservableValue
    }
}

private final class ObservableContains<Input: ObservableSetType>: _AbstractObservableValue<Bool> where Input.Change == SetChange<Input.Element> {
    let input: Input
    let member: Input.Element
    let _updates: AnySource<ValueUpdate<Bool>>

    init(input: Input, member: Input.Element) {
        self.input = input
        self.member = member
        self._updates = input.updates.flatMap { update in
            update.flatMap {
                let old = $0.removed.contains(member)
                let new = $0.inserted.contains(member)
                if old == new {
                    return nil
                }
                else {
                    return ValueChange(from: old, to: new)
                }
            }
        }
    }

    override var value: Bool {
        return input.contains(member)
    }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        _updates.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return _updates.remove(sink)
    }
}
