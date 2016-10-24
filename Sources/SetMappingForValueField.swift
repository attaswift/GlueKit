//
//  SetMappingForValueField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableSetType {
    /// Given an observable set and a closure that extracts an observable value from each element,
    /// return an observable set that contains the extracted field values contained in this set.
    ///
    /// - Parameter key: A mapping closure, extracting an observable value from an element of this set.
    public func map<Field: ObservableValueType>(_ key: @escaping (Element) -> Field) -> AnyObservableSet<Field.Value> where Field.Value: Hashable {
        return SetMappingForValueField<Self, Field>(parent: self, key: key).anyObservableSet
    }
}

class SetMappingForValueField<Parent: ObservableSetType, Field: ObservableValueType>: SetMappingBase<Field.Value> where Field.Value: Hashable {
    let parent: Parent
    let key: (Parent.Element) -> Field

    init(parent: Parent, key: @escaping (Parent.Element) -> Field) {
        self.parent = parent
        self.key = key
        super.init()
        parent.updates.add(parentSink)

        for e in parent.value {
            let field = key(e)
            field.updates.add(fieldSink)
            _ = self.insert(field.value)
        }
    }

    deinit {
        parent.updates.remove(parentSink)
        for e in parent.value {
            let field = key(e)
            field.updates.remove(fieldSink)
        }
    }

    private var parentSink: AnySink<SetUpdate<Parent.Element>> {
        return MethodSink(owner: self, identifier: 1, method: SetMappingForValueField.applyParentUpdate).anySink
    }

    private var fieldSink: AnySink<ValueUpdate<Field.Value>> {
        return MethodSink(owner: self, identifier: 2, method: SetMappingForValueField.applyFieldUpdate).anySink
    }

    private func applyParentUpdate(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            var transformedChange = SetChange<Element>()
            for e in change.removed {
                let field = key(e)
                let value = field.value
                field.updates.remove(fieldSink)
                if self.remove(value) {
                    transformedChange.remove(value)
                }
            }
            for e in change.inserted {
                let field = key(e)
                let value = field.value
                field.updates.add(fieldSink)
                if self.insert(value) {
                    transformedChange.insert(value)
                }
            }
            if !transformedChange.isEmpty {
                sendChange(transformedChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }

    private func applyFieldUpdate(_ update: ValueUpdate<Field.Value>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            if change.old == change.new { return }
            var transformedChange = SetChange<Element>()
            if self.remove(change.old) {
                transformedChange.remove(change.old)
            }
            if self.insert(change.new) {
                transformedChange.insert(change.new)
            }
            if !transformedChange.isEmpty {
                sendChange(transformedChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }
}
