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

private final class ArrayMappingForValueField<Parent: ObservableArrayType, Field: ObservableValueType>: ObservableArrayBase<Field.Value>, SignalDelegate {
    typealias Element = Field.Value
    typealias Base = Array<Element>
    typealias Change = ArrayChange<Element>

    private let parent: Parent
    private let key: (Parent.Element) -> Field

    private var state = TransactionState<Change>()
    private var parentConnection: Connection? = nil
    private var fieldConnections = RefList<Connection>()

    init(parent: Parent, key: @escaping (Parent.Element) -> Field) {
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

    override var updates: ArrayUpdateSource<Element> { return state.source(retainingDelegate: self) }

    func start(_ signal: Signal<Update<Change>>) {
        assert(parentConnection == nil && fieldConnections.isEmpty)
        let fields = parent.value.map(key)
        fieldConnections = RefList(fields.lazy.map { field in self.connectField(field) })
        parentConnection = parent.updates.connect { [unowned self] update in self.apply(update) }
    }

    func stop(_ signal: Signal<Update<Change>>) {
        assert(parentConnection != nil)
        parentConnection?.disconnect()
        fieldConnections.forEach { $0.disconnect() }
        parentConnection = nil
        fieldConnections.removeAll()
    }

    private func connectField(_ field: Field) -> Connection {
        var connection: Connection? = nil
        let c = field.updates.connect { [unowned self] update in self.apply(update, from: connection) }
        connection = c
        return c
    }

    private func apply(_ update: ValueUpdate<Element>, from connection: Connection?) {
        switch update {
        case .beginTransaction:
            state.begin()
        case .change(let change):
            let index = fieldConnections.index(of: connection!)!
            state.send(ArrayChange(initialCount: fieldConnections.count,
                                   modification: .replace(change.old, at: index, with: change.new)))
        case .endTransaction:
            state.end()
        }
    }

    private func apply(_ update: ArrayUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            state.begin()
        case .change(let change):
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
                state.send(newChange)
            }
        case .endTransaction:
            state.end()
        }
    }
}
