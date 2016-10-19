//
//  ValueMappingForSourceField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableValueType where Change == ValueChange<Value> {
    /// Map is an operator that implements key path coding and observing.
    /// Given an observable parent and a key that selects a child component (a.k.a "field") of its value that is a source,
    /// `map` returns a new source that can be used connect to the field indirectly through the parent.
    ///
    /// - Parameter key: An accessor function that returns a component of self (a field) that is a SourceType.
    ///
    /// - Returns: A new source that sends the same values as the current source returned by key in the parent.
    public func map<S: SourceType>(_ key: @escaping (Value) -> S) -> Source<S.SourceValue> {
        return ValueMappingForSourceField(parent: self, key: key).source
    }
}

/// A source of values for a Source field.
private final class ValueMappingForSourceField<Parent: ObservableValueType, Field: SourceType>: SignalDelegate, SourceType
where Parent.Change == ValueChange<Parent.Value> {

    typealias Value = Field.SourceValue

    let parent: Parent
    let key: (Parent.Value) -> Field

    var signal = OwningSignal<Value>()
    var fieldConnection: Connection? = nil
    var parentConnection: Connection? = nil

    func connect(_ sink: Sink<Value>) -> Connection { return signal.with(self).connect(sink) }

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self.parent = parent
        self.key = key
    }

    func start(_ signal: Signal<Value>) {
        assert(parentConnection == nil)
        let field = key(parent.value)
        parentConnection = parent.changes.connect { [unowned self] change in self.apply(change) }
        fieldConnection = field.connect(signal)
    }

    func stop(_ signal: Signal<Value>) {
        fieldConnection!.disconnect()
        parentConnection!.disconnect()
        fieldConnection = nil
        parentConnection = nil
    }

    private func apply(_ change: ValueChange<Parent.Value>) {
        let field = key(change.new)
        self.fieldConnection!.disconnect()
        self.fieldConnection = field.connect(signal.with(self))
    }
}
