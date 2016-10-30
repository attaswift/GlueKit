//
//  SetMappingForValueField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableSetType where Change == SetChange<Element> {
    /// Given an observable set and a closure that extracts an observable value from each element,
    /// return an observable set that contains the extracted field values contained in this set.
    ///
    /// - Parameter key: A mapping closure, extracting an observable value from an element of this set.
    public func map<Field: ObservableValueType>(_ key: @escaping (Element) -> Field) -> AnyObservableSet<Field.Value> where Field.Value: Hashable, Field.Change == ValueChange<Field.Value> {
        return SetMappingForValueField<Self, Field>(parent: self, key: key).anyObservableSet
    }
}

private struct ParentSink<Parent: ObservableSetType, Field: ObservableValueType>: UniqueOwnedSink
where Field.Value: Hashable, Parent.Change == SetChange<Parent.Element>, Field.Change == ValueChange<Field.Value> {
    typealias Owner = SetMappingForValueField<Parent, Field>

    unowned(unsafe) let owner: Owner

    func receive(_ update: SetUpdate<Parent.Element>) {
        owner.applyParentUpdate(update)
    }
}

private struct FieldSink<Parent: ObservableSetType, Field: ObservableValueType>: UniqueOwnedSink
where Field.Value: Hashable, Parent.Change == SetChange<Parent.Element>, Field.Change == ValueChange<Field.Value> {
    typealias Owner = SetMappingForValueField<Parent, Field>

    unowned(unsafe) let owner: Owner

    func receive(_ update: ValueUpdate<Field.Value>) {
        owner.applyFieldUpdate(update)
    }
}

class SetMappingForValueField<Parent: ObservableSetType, Field: ObservableValueType>: SetMappingBase<Field.Value>
where Field.Value: Hashable, Parent.Change == SetChange<Parent.Element>, Field.Change == ValueChange<Field.Value> {
    let parent: Parent
    let key: (Parent.Element) -> Field

    init(parent: Parent, key: @escaping (Parent.Element) -> Field) {
        self.parent = parent
        self.key = key
        super.init()
        parent.add(ParentSink(owner: self))

        for e in parent.value {
            let field = key(e)
            field.add(FieldSink(owner: self))
            _ = self.insert(field.value)
        }
    }

    deinit {
        parent.remove(ParentSink(owner: self))
        for e in parent.value {
            let field = key(e)
            field.remove(FieldSink(owner: self))
        }
    }

    func applyParentUpdate(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            var transformedChange = SetChange<Element>()
            for e in change.removed {
                let field = key(e)
                let value = field.value
                field.remove(FieldSink(owner: self))
                if self.remove(value) {
                    transformedChange.remove(value)
                }
            }
            for e in change.inserted {
                let field = key(e)
                let value = field.value
                field.add(FieldSink(owner: self))
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

    func applyFieldUpdate(_ update: ValueUpdate<Field.Value>) {
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
