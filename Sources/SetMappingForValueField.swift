//
//  SetMappingForValueField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableSetType {
    /// Given an observable set and a closure that extracts an observable value from each element,
    /// return an observable set that contains the extracted field values contained in this set.
    ///
    /// - Parameter key: A mapping closure, extracting an observable value from an element of this set.
    public func map<Field: ObservableValueType>(_ key: @escaping (Element) -> Field) -> ObservableSet<Field.Value> where Field.Value: Hashable {
        return SetMappingForValueField<Self, Field>(base: self, key: key).observableSet
    }
}

class SetMappingForValueField<S: ObservableSetType, Field: ObservableValueType>: MultiObservableSet<Field.Value> where Field.Value: Hashable {
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
            _ = self.insert(field.value)
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
            let value = field.value
            connections.removeValue(forKey: e)!.disconnect()
            if self.remove(value) {
                transformedChange.remove(value)
            }
        }
        for e in change.inserted {
            let field = key(e)
            let value = field.value
            let c = field.changes.connect { [unowned self] change in self.apply(change) }
            guard connections.updateValue(c, forKey: e) == nil else { fatalError("Invalid change: inserted element already in set") }
            if self.insert(value) {
                transformedChange.insert(value)
            }
        }
        if !transformedChange.isEmpty {
            signal.send(transformedChange)
        }
    }

    private func apply(_ change: SimpleChange<Field.Value>) {
        if change.old == change.new { return }
        var transformedChange = SetChange<Element>()
        if self.remove(change.old) {
            transformedChange.remove(change.old)
        }
        if self.insert(change.new) {
            transformedChange.insert(change.new)
        }
        if !transformedChange.isEmpty {
            signal.send(transformedChange)
        }
    }
}
