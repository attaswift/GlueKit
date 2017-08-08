//
//  TransactionState.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-22.
//  Copyright © 2015–2017 Károly Lőrentey.
//


internal class TransactionalSignal<Change: ChangeType>: Signal<Update<Change>> {
    typealias Value = Update<Change>

    var isInTransaction: Bool = false

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

protocol TransactionalThing: class, SignalDelegate {
    associatedtype Change: ChangeType
    
    var _signal: TransactionalSignal<Change>? { get set }
    var _transactionCount: Int { get set }
}

extension TransactionalThing {
    var signal: TransactionalSignal<Change> {
        if let signal = _signal { return signal }
        let signal = TransactionalSignal<Change>()
        signal.isInTransaction = _transactionCount > 0
        signal.delegate = self
        _signal = signal
        return signal
    }

    func beginTransaction() {
        _transactionCount += 1
        if _transactionCount == 1, let signal = _signal {
            signal.isInTransaction = true
            signal.send(.beginTransaction)
        }
    }
    
    func sendChange(_ change: Change) {
        precondition(_transactionCount > 0)
        _signal?.send(.change(change))
    }
    
    func sendIfConnected(_ change: @autoclosure () -> Change) {
        if isConnected {
            sendChange(change())
        }
    }
    
    func endTransaction() {
        precondition(_transactionCount > 0)
        _transactionCount -= 1
        if _transactionCount == 0, let signal = _signal {
            signal.isInTransaction = false
            signal.send(.endTransaction)
        }
    }
    
    public func send(_ update: Update<Change>) {
        switch update {
        case .beginTransaction: beginTransaction()
        case .change(let change): sendChange(change)
        case .endTransaction: endTransaction()
        }
    }
    
    var isInTransaction: Bool { return _transactionCount > 0 }
    var isConnected: Bool { return _signal?.isConnected ?? false }
    var isActive: Bool { return isInTransaction || isConnected }
    var isInOuterMostTransaction: Bool { return _transactionCount == 1 } // Used by KVO
}

public class TransactionalSource<Change: ChangeType>: _AbstractSource<Update<Change>>, TransactionalThing {
    internal var _signal: TransactionalSignal<Change>? = nil
    internal var _transactionCount = 0

    func activate() {
    }
    
    func deactivate() {
    }
    
    public override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
        signal.add(sink)
    }
    
    @discardableResult
    public override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
        return signal.remove(sink)
    }
}
