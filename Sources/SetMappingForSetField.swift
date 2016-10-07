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
        return SetMappingForSetField<Self, Field>(base: self, key: key).observableSet
    }
}

class SetMappingForSetField<S: ObservableSetType, Field: ObservableSetType>: SetMappingBase<Field.Element> {
    let base: S
    let key: (S.Element) -> Field

    var baseConnection: Connection? = nil
    var connections: [S.Element: Connection] = [:]

    init(base: S, key: @escaping (S.Element) -> Field) {
        self.base = base
        self.key = key
        super.init()
        baseConnection = base.changes.connect { [unowned self] change in self.apply(change) }

        for e in base.value {
            let field = key(e)
            connections[e] = field.changes.connect { [unowned self] change in self.apply(change) }
            for new in field.value {
                _ = self.insert(new)
            }
        }
    }

    deinit {
        baseConnection?.disconnect()
        connections.forEach { (_, c) in c.disconnect() }
    }

    private func apply(_ change: SetChange<S.Element>) {
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
            let c = field.changes.connect { [unowned self] change in self.apply(change) }
            guard connections.updateValue(c, forKey: e) == nil else { fatalError("Invalid change: inserted element already in set") }
            for i in field.value {
                if self.insert(i) {
                    transformedChange.insert(i)
                }
            }
        }
        if !transformedChange.isEmpty {
            signal.send(transformedChange)
        }
    }

    private func apply(_ change: SetChange<Field.Element>) {
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
            signal.send(transformedChange)
        }
    }
}
