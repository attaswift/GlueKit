//
//  SetMappingForSetField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableSetType {
    public func flatMap<Field: ObservableSetType>(_ key: @escaping (Element) -> Field) -> ObservableSet<Field.Element> {
        return SetMappingForSetField<Self, Field>(parent: self, key: key).observableSet
    }
}

class SetMappingForSetField<Parent: ObservableSetType, Field: ObservableSetType>: SetMappingBase<Field.Element> {
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
                let c = field.updates.connect { [unowned self] change in self.apply(change) }
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

    private func apply(_ update: SetUpdate<Field.Element>) {
        switch update {
        case .beginTransaction:
            begin()
        case .change(let change):
            var transformedChange = SetChange<Element>()
            for old in change.removed {
                if self.remove(old) {
                    transformedChange.remove(old)
                }
            }
            for new in change.inserted {
                if self.insert(new) {
                    transformedChange.insert(new)
                }
            }
            if !transformedChange.isEmpty {
                state.send(transformedChange)
            }
        case .endTransaction:
            end()
        }
    }
}
