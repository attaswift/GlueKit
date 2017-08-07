//
//  TwoWayBinding.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-24.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension UpdatableValueType {
    /// Create a two-way binding from self to a target updatable. The target is updated to the current value of self.
    /// All future updates will be synchronized between the two variables until the returned connection is disconnected.
    /// To prevent infinite cycles, you must provide an equality test that returns true if two values are to be
    /// considered equivalent.
    public func bind<Target: UpdatableValueType>(to target: Target, by areEquivalent: @escaping (Value, Value) -> Bool) -> Connection where Target.Value == Value {
        return BindConnection(source: self, target: target, by: areEquivalent)
    }
}

private enum  BindOrigin {
    case source
    case target
}

private struct BindSink<Source: UpdatableValueType, Target: UpdatableValueType>: OwnedSink
where Source.Value == Target.Value {
    typealias Owner = BindConnection<Source, Target>

    unowned let owner: Owner
    let origin: BindOrigin

    var identifier: BindOrigin { return origin }

    init(owner: Owner, origin: BindOrigin) {
        self.owner = owner
        self.origin = origin
    }

    private func send(_ update: Update<ValueChange<Source.Value>>) {
        switch origin {
        case .source:
            owner.target!.apply(update)
        case .target:
            owner.source!.apply(update)
        }
    }

    private var destinationValue: Source.Value {
        switch origin {
        case .source:
            return owner.target!.value
        case .target:
            return owner.source!.value
        }
    }

    func receive(_ update: Update<ValueChange<Source.Value>>) {
        switch update {
        case .beginTransaction:
            switch owner.transactionOrigin {
            case nil:
                owner.transactionOrigin = origin
                send(update)
            case .some(origin):
                preconditionFailure("Duplicate transaction")
            case .some(_):
                // Ignore
                break
            }
        case .change(let change):
            if !owner.areEquivalent!(change.new, destinationValue) {
                send(update)
            }
        case .endTransaction:
            switch owner.transactionOrigin {
            case nil:
                preconditionFailure("End received for nonexistent transaction")
            case .some(origin):
                send(update)
                owner.transactionOrigin = nil
            case .some(_):
                // Ignore
                break
            }
        }
    }
}

private final class BindConnection<Source: UpdatableValueType, Target: UpdatableValueType>: Connection
where Source.Value == Target.Value {
    typealias Value = Source.Value

    var areEquivalent: ((Value, Value) -> Bool)?
    var source: Source?
    var target: Target?
    var transactionOrigin: BindOrigin? = nil

    init(source: Source, target: Target, by areEquivalent: @escaping (Value, Value) -> Bool) {
        self.areEquivalent = areEquivalent
        self.source = source
        self.target = target
        super.init()

        source.add(BindSink(owner: self, origin: .source))
        precondition(transactionOrigin == nil, "Binding during an active transaction is not supported")
        target.add(BindSink(owner: self, origin: .target))
        precondition(transactionOrigin == nil, "Binding during an active transaction is not supported")

        if !areEquivalent(source.value, target.value) {
            target.value = source.value
        }
    }

    deinit {
        disconnect()
    }

    override func disconnect() {
        precondition(transactionOrigin == nil, "Unbinding during an active transaction is not supported")
        if let source = self.source {
            source.remove(BindSink(owner: self, origin: .source))
        }
        if let source = self.target {
            source.remove(BindSink(owner: self, origin: .target))
        }
        self.areEquivalent = nil
        self.source = nil
        self.target = nil
    }
}

extension UpdatableValueType where Value: Equatable {
    /// Create a two-way binding from self to a target variable. The target is updated to the current value of self.
    /// All future updates will be synchronized between the two variables until the returned connection is disconnected.
    /// To prevent infinite cycles, the variables aren't synched when a bound variable is set to a value that is equal
    /// to the value of its counterpart.
    public func bind<Target: UpdatableValueType>(to target: Target) -> Connection where Target.Value == Value {
        return self.bind(to: target, by: ==)
    }
}

extension Connector {
    @discardableResult
    public func bind<Source: UpdatableValueType, Target: UpdatableValueType>(_ source: Source, to target: Target, by areEquivalent: @escaping (Source.Value, Source.Value) -> Bool) -> Connection
        where Source.Value == Target.Value {
            return source.bind(to: target, by: areEquivalent).putInto(self)
    }

    @discardableResult
    public func bind<Value: Equatable, Source: UpdatableValueType, Target: UpdatableValueType>(_ source: Source, to target: Target) -> Connection
        where Source.Value == Value, Target.Value == Value {
            return self.bind(source, to: target, by: ==)
    }
}
