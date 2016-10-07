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
public final class ObservableSetReference<Element: Hashable>: ObservableSetBase<Element>, SignalDelegate {
    public typealias Base = Set<Element>
    public typealias Change = SetChange<Element>

    private var _target: ObservableSet<Element>
    private var _changes = OwningSignal<Change>()
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
            let change = SetChange(from: _target.value, to: target.observableSet.value)
            _target = target.observableSet
            _connection = target.changes.connect { change in self._changes.send(change) }
            _changes.send(change)
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
    public override var changes: Source<Change> { return _changes.with(self).source }

    internal func start(_ signal: Signal<Change>) {
        precondition(_connection == nil)
        _connection = _target.changes.connect { change in self._changes.send(change) }
    }

    internal func stop(_ signal: Signal<Change>) {
        precondition(_connection != nil)
        _connection!.disconnect()
        _connection = nil
    }
}
