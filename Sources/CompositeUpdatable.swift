//
//  CompositeUpdatable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension UpdatableValueType {
    public func combine<Other: UpdatableValueType>(_ other: Other) -> Updatable<(Value, Other.Value)> {
        return CompositeUpdatable(first: self, second: other).updatable
    }
}

public func combine<O1: UpdatableValueType, O2: UpdatableValueType>(_ o1: O1, _ o2: O2) -> Updatable<(O1.Value, O2.Value)> {
    return o1.combine(o2)
}

public func combine<O1: UpdatableValueType, O2: UpdatableValueType, O3: UpdatableValueType>(_ o1: O1, _ o2: O2, _ o3: O3) -> Updatable<(O1.Value, O2.Value, O3.Value)> {
    return o1.combine(o2).combine(o3)
        .map({ a, b in (a.0, a.1, b) },
             inverse: { v in ((v.0, v.1), v.2) })
}

public func combine<O1: UpdatableValueType, O2: UpdatableValueType, O3: UpdatableValueType, O4: UpdatableValueType>(_ o1: O1, _ o2: O2, _ o3: O3, _ o4: O4) -> Updatable<(O1.Value, O2.Value, O3.Value, O4.Value)> {
    return o1.combine(o2).combine(o3).combine(o4)
        .map({ a, b in (a.0.0, a.0.1, a.1, b) },
             inverse: { v in (((v.0, v.1), v.2), v.3) })
}

public func combine<O1: UpdatableValueType, O2: UpdatableValueType, O3: UpdatableValueType, O4: UpdatableValueType, O5: UpdatableValueType>(_ o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5) -> Updatable<(O1.Value, O2.Value, O3.Value, O4.Value, O5.Value)> {
    return o1.combine(o2).combine(o3).combine(o4).combine(o5)
        .map({ a, b in (a.0.0.0, a.0.0.1, a.0.1, a.1, b) },
             inverse: { v in ((((v.0, v.1), v.2), v.3), v.4) })
}

public func combine<O1: UpdatableValueType, O2: UpdatableValueType, O3: UpdatableValueType, O4: UpdatableValueType, O5: UpdatableValueType, O6: UpdatableValueType>(_ o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5, _ o6: O6) -> Updatable<(O1.Value, O2.Value, O3.Value, O4.Value, O5.Value, O6.Value)> {
    return o1.combine(o2).combine(o3).combine(o4).combine(o5).combine(o6)
        .map({ a, b in (a.0.0.0.0, a.0.0.0.1, a.0.0.1, a.0.1, a.1, b) },
             inverse: { v in (((((v.0, v.1), v.2), v.3), v.4), v.5) })
}

/// An Updatable that is a composite of two other updatables.
private final class CompositeUpdatable<A: UpdatableValueType, B: UpdatableValueType>: UpdatableValueType, SignalDelegate {
    typealias Value = (A.Value, B.Value)
    private let first: A
    private let second: B
    private var signal = OwningSignal<SimpleChange<Value>>()

    private var firstValue: A.Value? = nil
    private var secondValue: B.Value? = nil
    private var connections: (Connection, Connection)? = nil

    init(first: A, second: B) {
        self.first = first
        self.second = second
    }

    final var changes: Source<SimpleChange<Value>> { return signal.with(self).source }

    final var value: Value {
        get {
            if let v1 = firstValue, let v2 = secondValue { return (v1, v2) }
            return (first.value, second.value)
        }
        set {
            // Updating a composite updatable is tricky, because updating the components will trigger a synchronous update,
            // which can lead to us broadcasting intermediate states, which can result in infinite feedback loops.
            // To prevent this, we update our idea of most recent values before setting our component updatables.

            firstValue = newValue.0
            secondValue = newValue.1

            first.value = newValue.0
            second.value = newValue.1
        }
    }

    final func start(_ signal: Signal<SimpleChange<Value>>) {
        precondition(connections == nil)
        firstValue = first.value
        secondValue = second.value
        let c1 = first.changes.connect { [unowned self] change in
            let old = (change.old, self.secondValue!)
            let new = (change.new, self.secondValue!)
            self.firstValue = change.new
            signal.send(SimpleChange(from: old, to: new))
        }
        let c2 = second.changes.connect { [unowned self] change in
            let old = (self.firstValue!, change.old)
            let new = (self.firstValue!, change.new)
            self.secondValue = change.new
            signal.send(SimpleChange(from: old, to: new))
        }
        connections = (c1, c2)
    }

    final func stop(_ signal: Signal<SimpleChange<Value>>) {
        connections!.0.disconnect()
        connections!.1.disconnect()
        firstValue = nil
        secondValue = nil
        connections = nil
    }
}
