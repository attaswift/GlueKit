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

internal class ChangesSink<Change: ChangeType, Wrapped: SinkType>: SinkType where Wrapped.Value == Change {
    typealias Value = Update<Change>

    let wrapped: Wrapped
    var pending: Change? = nil

    init(_ wrapped: Wrapped) {
        self.wrapped = wrapped
    }

    func receive(_ update: Update<Change>) {
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
                    wrapped.receive(change)
                }
            }
        }
    }

    var hashValue: Int {
        return wrapped.hashValue
    }

    static func ==(left: ChangesSink, right: ChangesSink) -> Bool {
        return left.wrapped == right.wrapped
    }
}

internal class ChangesSource<Change: ChangeType, Updates: SourceType>: _AbstractSource<Change> where Updates.Value == Update<Change> {
    let updates: Updates
    init(_ updates: Updates) {
        self.updates = updates
    }

    override func add<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Change {
        return updates.add(ChangesSink(sink))
    }

    override func remove<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Change {
        return updates.remove(ChangesSink(sink))
    }
}

