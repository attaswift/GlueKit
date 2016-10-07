//
//  ArrayMappingForValueField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-10.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableArrayType {
    /// Return an observable array that consists of the values for the field specified by `key` for each element of this array.
    public func map<Field: ObservableValueType>(_ key: @escaping (Element) -> Field) -> ObservableArray<Field.Value> {
        return ArrayMappingForValueField(parent: self.observableArray, key: key).observableArray
    }
}

private final class ArrayMappingForValueField<Entity, Field: ObservableValueType>: ObservableArrayBase<Field.Value>, SignalDelegate {
    typealias Element = Field.Value
    typealias Base = Array<Element>
    typealias Change = ArrayChange<Element>

    private let parent: ObservableArray<Entity>
    private let key: (Entity) -> Field

    private var signal = OwningSignal<Change>()
    private var parentConnection: Connection? = nil
    private var fieldConnections = RefList<Connection>()

    init(parent: ObservableArray<Entity>, key: @escaping (Entity) -> Field) {
        self.parent = parent
        self.key = key
    }

    override var isBuffered: Bool { return false }

    override subscript(index: Int) -> Element {
        return key(parent[index]).value
    }

    override subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        return ArraySlice(parent[bounds].map { key($0).value })
    }

    override var value: [Element] {
        return parent.value.map { key($0).value }
    }

    override var count: Int { return parent.count }

    override var changes: Source<Change> { return signal.with(self).source }

    func start(_ signal: Signal<Change>) {
        assert(parentConnection == nil && fieldConnections.isEmpty)
        let fields = parent.value.map(key)
        fieldConnections = RefList(fields.lazy.map { field in self.connectField(field) })
        parentConnection = parent.changes.connect { [unowned self] change in self.apply(change) }
    }

    func stop(_ signal: Signal<Change>) {
        assert(parentConnection != nil)
        parentConnection?.disconnect()
        fieldConnections.forEach { $0.disconnect() }
        parentConnection = nil
        fieldConnections.removeAll()
    }

    private func connectField(_ field: Field) -> Connection {
        var connection: Connection? = nil
        let c = field.changes.connect { [unowned self] change in  self.apply(change, from: connection!) }
        connection = c
        return c
    }

    private func apply(_ change: SimpleChange<Element>, from connection: Connection) {
        let index = fieldConnections.index(of: connection)!
        signal.send(ArrayChange(initialCount: fieldConnections.count, modification: .replace(change.old, at: index, with: change.new)))
    }

    private func apply(_ change: ArrayChange<Entity>) {
        precondition(fieldConnections.count == change.initialCount)
        var newChange = ArrayChange<Element>(initialCount: change.initialCount)
        for mod in change.modifications {
            let start = mod.startIndex
            var i = start
            mod.forEachOldElement { old in
                fieldConnections[i].disconnect()
                i += 1
            }
            var cs: [Connection] = []
            mod.forEachNewElement { new in
                let field = key(new)
                cs.append(self.connectField(field))
            }
            fieldConnections.replaceSubrange(start ..< i, with: cs)
            newChange.add(mod.map { self.key($0).value })
        }
        precondition(fieldConnections.count == change.finalCount)
        if !newChange.isEmpty {
            signal.send(newChange)
        }
    }
}
