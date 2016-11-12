//
//  ComputedUpdatable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-11-11.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

private struct ComputedUpdatableSink<V>: UniqueOwnedSink {
    typealias Owner = ComputedUpdatable<V>

    unowned(unsafe) let owner: Owner

    func receive(_ value: Void) {
        owner.refresh()
    }
}

public final class ComputedUpdatable<Value>: _BaseUpdatableValue<Value> {
    public let getter: () -> Value
    public let setter: (Value) -> ()
    public let refreshSource: AnySource<Void>?

    private var _value: Value

    public init(getter: @escaping () -> Value,
                setter: @escaping (Value) -> (),
                refreshSource: AnySource<Void>? = nil) {
        self.getter = getter
        self.setter = setter
        self.refreshSource = refreshSource
        self._value = getter()
        super.init()
        refreshSource?.add(ComputedUpdatableSink(owner: self))
    }

    deinit {
        refreshSource?.remove(ComputedUpdatableSink(owner: self))
    }

    override func rawGetValue() -> Value {
        return _value
    }

    override func rawSetValue(_ value: Value) {
        setter(value)
        _value = getter()
    }

    public func refresh() {
        self.value = getter()
    }
}
