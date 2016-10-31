//
//  SetMappingForArrayField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableSetType where Change == SetChange<Element> {
    public func flatMap<Field: ObservableArrayType>(_ key: @escaping (Element) -> Field) -> AnyObservableSet<Field.Element> where Field.Element: Hashable, Field.Change == ArrayChange<Field.Element> {
        return SetMappingForArrayField<Self, Field>(parent: self, key: key).anyObservableSet
    }
}

private struct ParentSink<Parent: ObservableSetType, Field: ObservableArrayType>: UniqueOwnedSink
where Field.Element: Hashable, Parent.Change == SetChange<Parent.Element>, Field.Change == ArrayChange<Field.Element> {
    typealias Owner = SetMappingForArrayField<Parent, Field>

    unowned(unsafe) let owner: Owner

    func receive(_ update: SetUpdate<Parent.Element>) {
        owner.applyParentUpdate(update)
    }
}

private struct FieldSink<Parent: ObservableSetType, Field: ObservableArrayType>: UniqueOwnedSink
where Field.Element: Hashable, Parent.Change == SetChange<Parent.Element>, Field.Change == ArrayChange<Field.Element> {
    typealias Owner = SetMappingForArrayField<Parent, Field>

    unowned(unsafe) let owner: Owner

    func receive(_ update: ArrayUpdate<Field.Element>) {
        owner.applyFieldUpdate(update)
    }
}

class SetMappingForArrayField<Parent: ObservableSetType, Field: ObservableArrayType>: SetMappingBase<Field.Element>
where Field.Element: Hashable, Parent.Change == SetChange<Parent.Element>, Field.Change == ArrayChange<Field.Element> {
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
            for new in field.value {
                _ = self.insert(new)
            }
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
                field.remove(FieldSink(owner: self))
                for r in field.value {
                    if self.remove(r) {
                        transformedChange.remove(r)
                    }
                }
            }
            for e in change.inserted {
                let field = key(e)
                field.add(FieldSink(owner: self))
                for i in field.value {
                    if self.insert(i) {
                        transformedChange.insert(i)
                    }
                }
            }
            if !transformedChange.isEmpty {
                sendChange(transformedChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }

    func applyFieldUpdate(_ update: ArrayUpdate<Field.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            var transformedChange = SetChange<Element>()
            change.forEachOld { old in
                if self.remove(old) {
                    transformedChange.remove(old)
                }
            }
            change.forEachNew { new in
                if self.insert(new) {
                    transformedChange.insert(new)
                }
            }
            transformedChange = transformedChange.removingEqualChanges()
            if !transformedChange.isEmpty {
                sendChange(transformedChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }
}
