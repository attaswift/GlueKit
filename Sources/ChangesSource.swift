//
//  ChangesSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-22.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension ObservableType {
    /// A source that reports changes to the value of this observable.
    /// Changes reported correspond to complete transactions in `self.updates`.
    public var changes: AnySource<Change> {
        return ChangesSource(self).anySource
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

internal class ChangesSource<Observable: ObservableType>: _AbstractSource<Observable.Change> {
    typealias Change = Observable.Change

    let observable: Observable

    init(_ observable: Observable) {
        self.observable = observable
    }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Change {
        observable.add(ChangesSink(sink, withState: true))
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Change {
        let old = observable.remove(ChangesSink(sink, withState: false))
        return old.wrapped
    }
}

extension Connector {
    @discardableResult
    public func subscribe<Observable: ObservableType>(_ observable: Observable, to sink: @escaping (Observable.Change) -> Void) -> Connection {
        return observable.changes.subscribe(sink).putInto(self)
    }
}
