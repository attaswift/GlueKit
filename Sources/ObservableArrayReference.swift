//
//  ObservableArrayReference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-17.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

/// A mutable reference to an `ObservableArray` that's also an observable array.
/// You can switch to another target array without having to re-register subscribers.
public class ObservableArrayReference<Element>: ObservableArrayType, SignalDelegate {
    public typealias Base = [Element]
    public typealias Change = ArrayChange<Element>

    private var _target: ObservableArray<Element>
    private var _futureChanges = OwningSignal<Change, ObservableArrayReference>()
    private var _connection: Connection?

    public init() {
        _target = ObservableArray.emptyConstant()
    }
    
    public init<Target: ObservableArrayType>(target: Target) where Target.Element == Element {
        _target = target.observableArray
    }

    public func retarget<Target: ObservableArrayType>(to target: Target) where Target.Element == Element {
        if let c = _connection {
            c.disconnect()
            let change = ArrayChange(from: _target.value, to: target.value)
            _target = target.observableArray
            _connection = target.futureChanges.connect { change in self._futureChanges.send(change) }
            _futureChanges.send(change)
        }
        else {
            _target = target.observableArray
        }
    }

    public var isBuffered: Bool { return false }
    public var count: Int {
        return self._target.count
    }
    public var value: Base { return _target.value }
    public subscript(_ index: Int) -> Element { return _target[index] }
    public subscript(_ range: Range<Int>) -> ArraySlice<Element> { return _target[range] }
    public var futureChanges: Source<Change> { return _futureChanges.with(self).source }

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
