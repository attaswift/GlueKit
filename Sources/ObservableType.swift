//
//  ObservableValueType.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-04.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

public typealias UpdateSource<Change: ChangeType> = AnySource<Update<Change>>

public protocol ObservableType {
    associatedtype Change: ChangeType

    /// The current value of this observable.
    var value: Change.Value { get }

    /// A source that reports update transaction events for this observable.
    var updates: UpdateSource<Change> { get }
}

public protocol UpdatableType: ObservableType {
    /// The current value of this observable.
    ///
    /// The setter is nonmutating because the value ultimately needs to be stored in a reference type anyway.
    var value: Change.Value { get nonmutating set }

    func apply(_ update: Update<Change>)
}

extension UpdatableType {
    public func withTransaction<Result>(_ body: () -> Result) -> Result {
        apply(.beginTransaction)
        defer { apply(.endTransaction) }
        return body()
    }

    public func apply(_ change: Change) {
        apply(.beginTransaction)
        apply(.change(change))
        apply(.endTransaction)
    }
}

extension ObservableType {
    public func connect<Updatable: UpdatableType>(to updatable: Updatable) -> Connection
    where Updatable.Change == Change {
        updatable.apply(.beginTransaction)
        updatable.apply(.change(Change(from: updatable.value, to: self.value)))
        let connection = updates.connect { update in updatable.apply(update) }
        updatable.apply(.endTransaction)
        return connection
    }
}

extension Connector {
    @discardableResult
    public func connect<Observable: ObservableType>(_ observable: Observable, to sink: @escaping (Update<Observable.Change>) -> Void) -> Connection {
        return observable.updates.connect(sink).putInto(self)
    }

    @discardableResult
    public func connect<Observable: ObservableType>(_ observable: Observable, to sink: @escaping (Observable.Change) -> Void) -> Connection {
        return observable.changes.connect(sink).putInto(self)
    }
}
