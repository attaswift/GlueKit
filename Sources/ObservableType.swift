//
//  ObservableValueType.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-04.
//  Copyright © 2015–2017 Károly Lőrentey.
//

public protocol ObservableType {
    associatedtype Value
    associatedtype Change: ChangeType where Change.Value == Value

    /// The current value of this observable.
    var value: Value { get }

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change>

    @discardableResult
    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change>
}

extension ObservableType {
    /// A source that reports update transaction events for this observable.
    public var updates: UpdateSource<Self> {
        return UpdateSource(owner: self)
    }
}

extension ObservableType {
    /// A source that sends an empty value whenever the observable completes a transaction.
    public var tick: AnySource<Void> {
        return self.updates.flatMap { if case .endTransaction = $0 { return () }; return nil }
    }
}

public struct UpdateSource<Observable: ObservableType>: SourceType {
    public typealias Value = Update<Observable.Change>

    private let owner: Observable

    init(owner: Observable) {
        self.owner = owner
    }

    public func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        owner.add(sink)
    }

    @discardableResult
    public func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
        return owner.remove(sink)
    }
}

public protocol UpdatableType: ObservableType {
    /// The current value of this observable.
    ///
    /// The setter is nonmutating because the value ultimately needs to be stored in a reference type anyway.
    var value: Value { get nonmutating set }

    func apply(_ update: Update<Change>)
}

extension UpdatableType {
    public func withTransaction<Result>(_ body: () -> Result) -> Result {
        apply(.beginTransaction)
        defer { apply(.endTransaction) }
        return body()
    }

    public func apply(_ change: Change) {
        if !change.isEmpty {
            apply(.beginTransaction)
            apply(.change(change))
            apply(.endTransaction)
        }
    }
}

extension ObservableType {
    public func subscribe<Updatable: UpdatableType>(to updatable: Updatable) -> Connection
    where Updatable.Change == Change {
        updatable.apply(.beginTransaction)
        updatable.apply(.change(Change(from: updatable.value, to: self.value)))
        let connection = updates.subscribe { update in updatable.apply(update) }
        updatable.apply(.endTransaction)
        return connection
    }
}

extension Connector {
    @discardableResult
    public func subscribe<Observable: ObservableType>(_ observable: Observable, to sink: @escaping (Update<Observable.Change>) -> Void) -> Connection {
        return observable.updates.subscribe(sink).putInto(self)
    }
}
