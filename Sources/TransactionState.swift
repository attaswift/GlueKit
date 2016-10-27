//
//  TransactionState.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-22.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//


private class TransactionSignal<Change: ChangeType>: Signal<Update<Change>> {
    typealias Value = Update<Change>

    var isInTransaction: Bool

    init(owner: SignalDelegate, isInTransaction: Bool) {
        self.isInTransaction = isInTransaction
        super.init(delegate: owner)
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

    public override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        if self.isInTransaction {
            // Make sure the new subscriber knows we're in the middle of a transaction.
            sink.receive(.beginTransaction)
        }
        super.add(sink)
    }

    @discardableResult
    public override func remove<Sink: SinkType>(_ sink: Sink) -> AnySink<Value> where Sink.Value == Value {
        let old = super.remove(sink)
        if self.isInTransaction {
            // Wave goodbye by sending a virtual endTransaction that makes state management easier.
            old.receive(.endTransaction)
        }
        return old
    }
}

private final class UpdateSource<Change: ChangeType>: _AbstractSource<Update<Change>> {
    let owner: AnyObject
    let signal: TransactionSignal<Change>

    init(owner: AnyObject, signal: TransactionSignal<Change>) {
        self.owner = owner
        self.signal = signal
    }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        signal.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> AnySink<Update<Change>> where Sink.Value == Update<Change> {
        return signal.remove(sink)
    }

}

internal struct TransactionState<Change: ChangeType> {
    fileprivate var signal: TransactionSignal<Change>? = nil
    private var transactionCount = 0

    mutating func source(delegate: SignalDelegate) -> AnySource<Update<Change>> {
        if let signal = self.signal {
            assert(signal.delegate === delegate)
            return UpdateSource(owner: delegate, signal: signal).anySource
        }
        let signal = TransactionSignal<Change>(owner: delegate, isInTransaction: self.isChanging)
        self.signal = signal
        return UpdateSource(owner: delegate, signal: signal).anySource
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

open class TransactionalSource<Change: ChangeType>: _AbstractSource<Update<Change>>, SignalDelegate {
    public typealias Value = Update<Change>

    internal var state = TransactionState<Change>()

    public final override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        state.source(delegate: self).add(sink)
    }

    @discardableResult
    public final override func remove<Sink: SinkType>(_ sink: Sink) -> AnySink<Value> where Sink.Value == Value {
        return state.signal!.remove(sink)
    }

    func activate() {
    }

    func deactivate() {
    }
}
