//
//  ArrayReference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-17.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

/// A mutable reference to an `ObservableArray` that's also an observable array.
/// You can switch to another target array without having to re-register subscribers.
public final class ObservableArrayReference<Element>: ObservableArrayBase<Element>, SignalDelegate {
    public typealias Base = [Element]
    public typealias Change = ArrayChange<Element>

    private var _target: ObservableArray<Element>
    private var _state = TransactionState<Change>()
    private var _connection: Connection?

    public override init() {
        _target = ObservableArray.emptyConstant()
        super.init()
    }
    
    public init<Target: ObservableArrayType>(target: Target) where Target.Element == Element {
        _target = target.observableArray
        super.init()
    }

    public func retarget<Target: ObservableArrayType>(to target: Target) where Target.Element == Element {
        if let c = _connection {
            _state.begin()
            c.disconnect()
            let change = ArrayChange(from: _target.value, to: target.value)
            _target = target.observableArray
            _connection = target.updates.connect { [unowned self] update in self._state.send(update) }
            _state.send(change)
            _state.end()
        }
        else {
            _target = target.observableArray
        }
    }

    public override var isBuffered: Bool { return false }
    public override subscript(_ index: Int) -> Element { return _target[index] }
    public override subscript(_ range: Range<Int>) -> ArraySlice<Element> { return _target[range] }
    public override var value: [Element] { return _target.value }
    public override var count: Int { return self._target.count }
    public override var updates: ArrayUpdateSource<Element> { return _state.source(retainingDelegate: self) }

    internal func start(_ signal: Signal<ArrayUpdate<Element>>) {
        precondition(_connection == nil)
        _connection = _target.updates.connect { [unowned self] update in self._state.send(update) }
    }

    internal func stop(_ signal: Signal<ArrayUpdate<Element>>) {
        precondition(_connection != nil)
        _connection!.disconnect()
        _connection = nil
    }
}
