//
//  ChangesSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-22.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableType {
    /// A source that reports changes to the value of this observable.
    /// Changes reported correspond to complete transactions in `self.updates`.
    public var changes: AnySource<Change> {
        return ChangesSource(self.updates).anySource
    }
}

private class ChangesSinkState<Change: ChangeType> {
    typealias Value = Update<Change>

    var pending: Change? = nil

    func apply(_ update: Update<Change>) -> Change? {
        switch update {
        case .beginTransaction:
            precondition(pending == nil)
        case .change(let change):
            if pending == nil {
                pending = change
            }
            else {
                pending!.merge(with: change)
            }
        case .endTransaction:
            if let change = pending {
                pending = nil
                if !change.isEmpty {
                    return change
                }
            }
        }
        return nil
    }
}

private struct ChangesSink<Wrapped: SinkType>: SinkType where Wrapped.Value: ChangeType {
    typealias Change = Wrapped.Value
    typealias Value = Update<Change>

    let wrapped: Wrapped
    let state: ChangesSinkState<Change>?

    init(_ wrapped: Wrapped, withState needState: Bool) {
        self.wrapped = wrapped
        self.state = needState ? ChangesSinkState<Change>() : nil
    }

    func receive(_ update: Update<Change>) {
        if let change = state?.apply(update) {
            wrapped.receive(change)
        }
    }

    var hashValue: Int {
        return wrapped.hashValue
    }

    static func ==(left: ChangesSink, right: ChangesSink) -> Bool {
        return left.wrapped == right.wrapped
    }
}

internal class ChangesSource<Change: ChangeType, Updates: SourceType>: _AbstractSource<Change>
where Updates.Value == Update<Change> {
    let updates: Updates

    init(_ updates: Updates) {
        self.updates = updates
    }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Change {
        updates.add(ChangesSink(sink, withState: true))
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> AnySink<Change> where Sink.Value == Change {
        let old: ChangesSink<Sink> = updates.remove(ChangesSink(sink, withState: false)).opened()!
        return old.wrapped.anySink
    }
}
