//
//  Observable Transformations.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableValueType where Change == SimpleChange<Value> {
    public func buffered() -> Observable<Value> {
        return BufferedObservableValue(self).observable
    }
}

internal class BufferedObservableValue<Base: ObservableValueType>: AbstractObservableBase<Base.Value>
where Base.Change == SimpleChange<Base.Value> {
    typealias Value = Base.Value

    private var base: Base

    var _value: Base.Value
    var signal = ChangeSignal<Change>()
    var connection: Connection? = nil

    init(_ base: Base) {
        self.base = base
        self._value = base.value
        super.init()

        connection = base.changeEvents.connect { [unowned self] event in
            switch event {
            case .willChange:
                self.signal.willChange()
            case .didNotChange:
                self.signal.didNotChange()
            case .didChange(let change):
                let old = self._value
                self._value = change.new
                self.signal.didChange(Change(from: old, to: change.new))
            }
        }
    }

    deinit {
        connection!.disconnect()
    }

    override var value: Base.Value { return _value }
    override var changeEvents: Source<ChangeEvent<Change>> { return signal.source(holding: self) }
}

