//
//  TransactionState.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-22.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//


internal protocol LazyObserver: class {
    func startObserving()
    func stopObserving()
}

extension LazyObserver {
    public func startObserving() {}
    public func stopObserving() {}
}

private class TransactionSignal<Change: ChangeType>: Signal<Update<Change>> {
    typealias Value = Update<Change>

    let owner: LazyObserver
    var isInTransaction: Bool

    init(owner: LazyObserver, isInTransaction: Bool) {
        self.owner = owner
        self.isInTransaction = isInTransaction
    }

    func begin() {
        assert(!isInTransaction)
        isInTransaction = true
        send(.beginTransaction)
    }

    func end() {
        assert(isInTransaction)
        isInTransaction = false
        send(.endTransaction)
    }

    func send(_ change: Change) {
        assert(isInTransaction)
        send(.change(change))
    }

    @discardableResult
    public override func add<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Value {
        if self.isInTransaction {
            // Make sure the new subscriber knows we're in the middle of a transaction.
            sink.receive(.beginTransaction)
        }
        let first = super.add(sink)
        if first {
            owner.startObserving()
        }
        return first
    }

    @discardableResult
    public override func remove<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Value {
        let last = super.remove(sink)
        if last {
            owner.stopObserving()
        }
        if self.isInTransaction {
            // Wave goodbye by sending a virtual endTransaction that makes state management easier.
            sink.receive(.endTransaction)
        }
        return last
    }
}

internal struct TransactionState<Change: ChangeType> {
    private weak var signal: TransactionSignal<Change>? = nil
    private var transactionCount = 0

    mutating func source(retaining owner: LazyObserver) -> AnySource<Update<Change>> {
        if let signal = self.signal {
            assert(signal.owner === owner)
            return signal.anySource
        }
        let signal = TransactionSignal<Change>(owner: owner, isInTransaction: self.isChanging)
        self.signal = signal
        return signal.anySource
    }

    var isChanging: Bool { return transactionCount > 0 }
    var isConnected: Bool { return signal?.isConnected ?? false }
    var isActive: Bool { return isChanging || isConnected }

    mutating func begin() {
        transactionCount += 1
        if transactionCount == 1 {
            signal?.begin()
        }
    }

    mutating func end() {
        precondition(transactionCount > 0)
        transactionCount -= 1
        if transactionCount == 0 {
            signal?.end()
        }
    }

    func send(_ change: Change) {
        precondition(transactionCount > 0)
        signal?.send(change)
    }

    func sendIfConnected(_ change: @autoclosure () -> Change) {
        precondition(transactionCount > 0)
        if let signal = signal, signal.isConnected {
            signal.send(change())
        }
    }

    func sendLater(_ change: Change) {
        precondition(transactionCount > 0)
        signal?.sendLater(.change(change))
    }

    func sendNow() {
        precondition(transactionCount > 0)
        signal?.sendNow()
    }

    mutating func send(_ update: Update<Change>) {
        switch update {
        case .beginTransaction: begin()
        case .change(let change): send(change)
        case .endTransaction: end()
        }
    }
}
