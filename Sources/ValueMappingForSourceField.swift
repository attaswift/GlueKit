//
//  ValueMappingForSourceField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension ObservableValueType {
    /// Map is an operator that implements key path coding and observing.
    /// Given an observable parent and a key that selects a child component (a.k.a "field") of its value that is a source,
    /// `map` returns a new source that can be used subscribe to the field indirectly through the parent.
    ///
    /// - Parameter key: An accessor function that returns a component of self (a field) that is a SourceType.
    ///
    /// - Returns: A new source that sends the same values as the current source returned by key in the parent.
    public func map<Source: SourceType>(_ key: @escaping (Value) -> Source) -> AnySource<Source.Value> {
        return ValueMappingForSourceField(parent: self, key: key).anySource
    }
}

/// A source of values for a Source field.
private final class ValueMappingForSourceField<Parent: ObservableValueType, Field: SourceType>: SignalerSource<Field.Value> {
    typealias Value = Field.Value

    private struct SourceFieldSink: UniqueOwnedSink {
        typealias Owner = ValueMappingForSourceField

        unowned let owner: Owner

        func receive(_ update: ValueUpdate<Parent.Value>) {
            owner.applyParentUpdate(update)
        }
    }

    let parent: Parent
    let key: (Parent.Value) -> Field

    private var _field: Field? = nil

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self.parent = parent
        self.key = key
    }

    override func activate() {
        precondition(_field == nil)
        let field = key(parent.value)
        _field = field
        parent.add(SourceFieldSink(owner: self))
        field.add(signal.asSink)
    }

    override func deactivate() {
        _field!.remove(signal.asSink)
        _field = nil
        parent.remove(SourceFieldSink(owner: self))
    }

    func applyParentUpdate(_ update: ValueUpdate<Parent.Value>) {
        switch update {
        case .beginTransaction:
            break
        case .change(let change):
            let field = key(change.new)
            _field!.remove(signal.asSink)
            _field = field
            field.add(signal.asSink)
        case .endTransaction:
            break
        }
    }
}
