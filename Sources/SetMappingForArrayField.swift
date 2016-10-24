//
//  SetMappingForArrayField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableSetType {
    public func flatMap<Field: ObservableArrayType>(_ key: @escaping (Element) -> Field) -> ObservableSet<Field.Element> where Field.Element: Hashable {
        return SetMappingForArrayField<Self, Field>(parent: self, key: key).observableSet
    }
}

class SetMappingForArrayField<Parent: ObservableSetType, Field: ObservableArrayType>: SetMappingBase<Field.Element> where Field.Element: Hashable {
    let parent: Parent
    let key: (Parent.Element) -> Field

    var baseConnection: Connection? = nil
    var connections: [Parent.Element: Connection] = [:]

    init(parent: Parent, key: @escaping (Parent.Element) -> Field) {
        self.parent = parent
        self.key = key
        super.init()
        baseConnection = parent.updates.connect { [unowned self] in self.apply($0) }

        for e in parent.value {
            let field = key(e)
            connections[e] = field.updates.connect { [unowned self] in self.apply($0) }
            for new in field.value {
                _ = self.insert(new)
            }
        }
    }

    deinit {
        baseConnection?.disconnect()
        connections.forEach { (_, c) in c.disconnect() }
    }

    private func apply(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            begin()
        case .change(let change):
            var transformedChange = SetChange<Element>()
            for e in change.removed {
                let field = key(e)
                connections.removeValue(forKey: e)!.disconnect()
                for r in field.value {
                    if self.remove(r) {
                        transformedChange.remove(r)
                    }
                }
            }
            for e in change.inserted {
                let field = key(e)
                let c = field.updates.connect { [unowned self] in self.apply($0) }
                guard connections.updateValue(c, forKey: e) == nil else { fatalError("Invalid change: inserted element already in set") }
                for i in field.value {
                    if self.insert(i) {
                        transformedChange.insert(i)
                    }
                }
            }
            if !transformedChange.isEmpty {
                state.send(transformedChange)
            }
        case .endTransaction:
            end()
        }
    }

    private func apply(_ update: ArrayUpdate<Field.Element>) {
        switch update {
        case .beginTransaction:
            begin()
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
                state.send(transformedChange)
            }
        case .endTransaction:
            end()
        }
    }
}
