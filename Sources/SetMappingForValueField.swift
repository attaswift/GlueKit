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
        return SetMappingForValueField<Self, Field>(parent: self, key: key).observableSet
    }
}

class SetMappingForValueField<Parent: ObservableSetType, Field: ObservableValueType>: SetMappingBase<Field.Value> where Field.Value: Hashable {
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
            _ = self.insert(field.value)
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
                let value = field.value
                connections.removeValue(forKey: e)!.disconnect()
                if self.remove(value) {
                    transformedChange.remove(value)
                }
            }
            for e in change.inserted {
                let field = key(e)
                let value = field.value
                let c = field.updates.connect { [unowned self] in self.apply($0) }
                guard connections.updateValue(c, forKey: e) == nil else { fatalError("Invalid change: inserted element already in set") }
                if self.insert(value) {
                    transformedChange.insert(value)
                }
            }
            if !transformedChange.isEmpty {
                state.send(transformedChange)
            }
        case .endTransaction:
            end()
        }
    }

    private func apply(_ update: ValueUpdate<Field.Value>) {
        switch update {
        case .beginTransaction:
            begin()
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
                state.send(transformedChange)
            }
        case .endTransaction:
            end()
        }
    }
}
