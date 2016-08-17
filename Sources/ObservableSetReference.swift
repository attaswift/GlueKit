//
//  ObservableSetReference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-17.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

/// A mutable reference to an `ObservableSet` that's also an observable set.
/// You can switch to another target set without having to re-register subscribers.
public class ObservableSetReference<Element: Hashable>: ObservableSetType, SignalDelegate {
    public typealias Base = Set<Element>
    public typealias Change = SetChange<Element>

    public typealias Index = Base.Index
    public typealias IndexDistance = Base.IndexDistance
    public typealias Indices = Base.Indices
    public typealias Iterator = Base.Iterator
    public typealias SubSequence = Base.SubSequence

    private var _target: ObservableSet<Element>
    private var _futureChanges = Signal<Change>()
    private var _connection: Connection?

    public init<Target: ObservableSetType>(target: Target) where Target.Element == Element {
        _target = target.observableSet
    }

    public func retarget<Target: ObservableSetType>(to target: Target) where Target.Element == Element {
        if let c = _connection {
            c.disconnect()
            let change = SetChange(from: _target.value, to: target.observableSet.value)
            _target = target.observableSet
            _connection = target.futureChanges.connect { change in self._futureChanges.send(change) }
            _futureChanges.send(change)
        }
        else {
            _target = target.observableSet
        }
    }

    public var value: Set<Element> { return _target.value }
    public var futureChanges: Source<Change> { return _futureChanges.source }

    internal func start(_ signal: Signal<Change>) {
        precondition(_connection == nil)
        _connection = _target.futureChanges.connect { change in self._futureChanges.send(change) }
    }

    internal func stop(_ signal: Signal<Change>) {
        precondition(_connection != nil)
        _connection!.disconnect()
        _connection = nil
    }
}
