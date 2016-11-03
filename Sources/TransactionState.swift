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
    public override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
        let old = super.remove(sink)
        if self.isInTransaction {
            // Wave goodbye by sending a virtual endTransaction that makes state management easier.
            old.receive(.endTransaction)
        }
        return old
    }
}

internal struct TransactionState<Change: ChangeType> {
    fileprivate var _signal: TransactionSignal<Change>? = nil
    private var _transactionCount = 0

    private mutating func signal(delegate: SignalDelegate) -> TransactionSignal<Change> {
        if let signal = _signal {
            precondition(signal.delegate === delegate)
            return signal
        }
        let signal = TransactionSignal<Change>(owner: delegate, isInTransaction: self.isChanging)
        _signal = signal
        return signal
    }

    mutating func add<Sink: SinkType>(_ sink: Sink, with delegate: SignalDelegate) where Sink.Value == Update<Change> {
        self.signal(delegate: delegate).add(sink)
    }

    @discardableResult
    mutating func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return _signal!.remove(sink)
    }

    var isChanging: Bool { return _transactionCount > 0 }
    var isConnected: Bool { return _signal?.isConnected ?? false }
    var isActive: Bool { return isChanging || isConnected }
    var isInOuterMostTransaction: Bool { return _transactionCount == 1 } // Used by KVO

    mutating func begin() {
        _transactionCount += 1
        if _transactionCount == 1 {
            _signal?.begin()
        }
    }

    mutating func end() {
        precondition(_transactionCount > 0)
        _transactionCount -= 1
        if _transactionCount == 0 {
            _signal?.end()
        }
    }

    func send(_ change: Change) {
        precondition(_transactionCount > 0)
        _signal?.send(change)
    }

    func sendIfConnected(_ change: @autoclosure () -> Change) {
        precondition(_transactionCount > 0)
        if let signal = _signal, signal.isConnected {
            signal.send(change())
        }
    }

    func sendLater(_ change: Change) {
        precondition(_transactionCount > 0)
        _signal?.sendLater(.change(change))
    }

    func sendNow() {
        precondition(_transactionCount > 0)
        _signal?.sendNow()
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
        state.add(sink, with: self)
    }

    @discardableResult
    public final override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
        return state.remove(sink)
    }

    func activate() {
    }

    func deactivate() {
    }
}
