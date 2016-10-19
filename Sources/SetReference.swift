//
//  SetReference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-17.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

/// A mutable reference to an `ObservableSet` that's also an observable set.
/// You can switch to another target set without having to re-register subscribers.
public final class ObservableSetReference<Element: Hashable>: _ObservableSetBase<Element>, SignalDelegate {
    public typealias Base = Set<Element>
    public typealias Change = SetChange<Element>

    private var _target: ObservableSet<Element>
    private var _state = TransactionState<Change>()
    private var _connection: Connection?

    public override init() {
        _target = ObservableSet.emptyConstant()
        super.init()
    }

    public init<Target: ObservableSetType>(target: Target) where Target.Element == Element {
        _target = target.observableSet
        super.init()
    }

    public func retarget<Target: ObservableSetType>(to target: Target) where Target.Element == Element {
        if let c = _connection {
            c.disconnect()
            _state.begin()
            let change = SetChange(from: _target.value, to: target.observableSet.value)
            _target = target.observableSet
            _state.send(change)
            _connection = target.updates.connect { update in self._state.send(update) }
            _state.end()
        }
        else {
            _target = target.observableSet
        }
    }

    public override var isBuffered: Bool { return false }
    public override var count: Int { return _target.count }
    public override var value: Set<Element> { return _target.value }
    public override func contains(_ member: Element) -> Bool { return _target.contains(member) }
    public override func isSubset(of other: Set<Element>) -> Bool { return _target.isSubset(of: other) }
    public override func isSuperset(of other: Set<Element>) -> Bool { return _target.isSuperset(of: other) }
    public override var updates: SetUpdateSource<Element> { return _state.source(retainingDelegate: self) }

    internal func start(_ signal: Signal<Update<Change>>) {
        precondition(_connection == nil)
        _connection = _target.updates.connect { update in self._state.send(update) }
    }

    internal func stop(_ signal: Signal<Update<Change>>) {
        precondition(_connection != nil)
        _connection!.disconnect()
        _connection = nil
    }
}
