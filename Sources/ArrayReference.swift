//
//  ArrayReference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-17.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//


/// A mutable reference to an `AnyObservableArray` that's also an observable array.
/// You can switch to another target array without having to re-register subscribers.
public final class ObservableArrayReference<Element>: _BaseObservableArray<Element> {
    public typealias Base = [Element]
    public typealias Change = ArrayChange<Element>

    private var _target: AnyObservableArray<Element>

    public override init() {
        _target = AnyObservableArray.emptyConstant()
        super.init()
    }
    
    public init<Target: ObservableArrayType>(target: Target) where Target.Element == Element {
        _target = target.anyObservableArray
        super.init()
    }

    public func retarget<Target: ObservableArrayType>(to target: Target) where Target.Element == Element {
        if isConnected {
            beginTransaction()
            _target.updates.remove(sink)
            let change = ArrayChange(from: _target.value, to: target.value)
            _target = target.anyObservableArray
            _target.updates.add(sink)
            sendChange(change)
            endTransaction()
        }
        else {
            _target = target.anyObservableArray
        }
    }

    public override var isBuffered: Bool { return false }
    public override subscript(_ index: Int) -> Element { return _target[index] }
    public override subscript(_ range: Range<Int>) -> ArraySlice<Element> { return _target[range] }
    public override var value: [Element] { return _target.value }
    public override var count: Int { return self._target.count }

    private var sink: AnySink<ArrayUpdate<Element>> {
        return MethodSink(owner: self, identifier: 0, method: ObservableArrayReference.apply).anySink
    }
    private func apply(_ update: ArrayUpdate<Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            sendChange(change)
        case .endTransaction:
            endTransaction()
        }
    }

    public override func startObserving() {
        _target.updates.add(sink)
    }

    public override func stopObserving() {
        _target.updates.remove(sink)
    }
}
