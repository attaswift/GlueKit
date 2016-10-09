//
//  Observable Transformations.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableValueType {
    public func buffered() -> Observable<Value> {
        return BufferedObservableValue(self).observable
    }
}

internal class BufferedObservableValue<Base: ObservableValueType>: ObservableBoxBase<Base.Value> {
    typealias Value = Base.Value

    private var base: Base

    var _value: Base.Value
    var signal = OwningSignal<SimpleChange<Value>>()
    var connection: Connection? = nil

    init(_ base: Base) {
        self.base = base
        self._value = base.value
        super.init()

        connection = base.changes.connect { [unowned self] change in
            let old = self._value
            self._value = change.new
            self.signal.send(.init(from: old, to: change.new))
        }
    }

    deinit {
        connection!.disconnect()
    }

    override var value: Base.Value { return _value }
    override var changes: Source<SimpleChange<Base.Value>> { return signal.with(retained: self).source }
}

