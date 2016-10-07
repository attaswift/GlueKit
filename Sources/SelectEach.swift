//
//  flatMap.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-10.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation
import BTree

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

extension ObservableArrayType {
    public func flatMap<Field: ObservableArrayType>(_ key: @escaping (Element) -> Field) -> ObservableArray<Field.Element> {
        let selector = ArrayMappingForArrayField<Self, Field>(parent: self, key: key)
        return selector.observableArray
    }
}

/// Maintains an index mapping for an operation mapping an array of arrays into a single flat array.
private struct IndexMapping {
    // TODO: A weight-augmented tree-backed list would work much better here.

    private var postindices: SortedSet<Int> = [0] // Always ends with the overall count of elements.
    // We don't have a SortedBag (yet), so empty arrays cause some elements in postindices to collapse. :-(
    // Keep track of preindices whose value is empty here, and take this into account in all algorithms below.
    private var emptyPreindices = SortedSet<Int>()

    var precount: Int { return postindices.count - 1 + emptyPreindices.count }
    var postcount: Int { return postindices.last! }

    private func empties(before preindex: Int) -> Int {
        guard let i = emptyPreindices.highestIndex(below: preindex) else { return 0 }
        return emptyPreindices.offset(of: i) + 1
    }

    func preindex(for postindex: Int) -> (preindex: Int, offset: Int) {
        let p = postindices.highestIndex(notAbove: postindex)!
        let start = postindices[p]
        var preindex = postindices.offset(of: p)
        if var i = emptyPreindices.highestIndex(notAbove: preindex) {
            preindex += emptyPreindices.offset(of: i) + 1
            emptyPreindices.formIndex(after: &i)
            while emptyPreindices.offset(of: i) != emptyPreindices.count && emptyPreindices[i] <= preindex {
                preindex += 1
                emptyPreindices.formIndex(after: &i)
            }
        }
        return (preindex, postindex - start)
    }

    func postindex(for preindex: Int) -> Int {
        let empties = self.empties(before: preindex)
        let offset = preindex - empties
        return postindices[offset]
    }

    mutating func appendArray(withCount count: Int) {
        let postcount = self.postcount
        if count == 0 {
            emptyPreindices.insert(precount)
        }
        postindices.insert(postcount + count)
    }

    mutating func replaceArrays(in prerange: Range<Int>, withCounts counts: [Int]) {
        let postrange: Range<Int> = postindex(for: prerange.lowerBound) ..< postindex(for: prerange.upperBound)
        let postdelta = counts.reduce(0, +) - postrange.count
        postindices.subtract(elementsIn: postrange)
        postindices.shift(startingAt: postrange.upperBound, by: postdelta)

        let predelta = counts.count - prerange.count
        emptyPreindices.subtract(elementsIn: prerange)
        emptyPreindices.shift(startingAt: prerange.upperBound, by: predelta)

        var poststart = postrange.lowerBound
        for i in 0 ..< counts.count {
            let count = counts[i]
            if count == 0 {
                emptyPreindices.insert(prerange.lowerBound + i)
            }
            postindices.insert(poststart)
            poststart += count
        }
    }

    mutating func setCount(forArrayAt preindex: Int, from old: Int, to new: Int) {
        if old == new { return }
        let start = self.postindex(for: preindex)
        if old == 0 {
            emptyPreindices.remove(preindex)
            postindices.shift(startingAt: start, by: new)
            postindices.insert(start)
        }
        else if new == 0 {
            emptyPreindices.insert(preindex)
            postindices.shift(startingAt: start + old, by: -old)
        }
        else {
            postindices.shift(startingAt: start + old, by: new - old)
        }
    }
}

private final class ArrayMappingForArrayField<Parent: ObservableArrayType, Field: ObservableArrayType>: ObservableArrayBase<Field.Element> {
    typealias Element = Field.Element

    private let parent: Parent
    private let key: (Parent.Element) -> Field

    private var signal = OwningSignal<Change>()

    private var parentConnection: Connection? = nil
    private var fieldConnections = RefList<Connection>([])
    private var indexMapping = IndexMapping() // This always has an extra element at the end with the count of all elements

    init(parent: Parent, key: @escaping (Parent.Element) -> Field) {
        self.parent = parent
        self.key = key
        super.init()

        parentConnection = parent.changes.connect { [unowned self] change in self.apply(change) }
        for pe in parent.value {
            let field = key(pe)
            fieldConnections.append(connectField(field))
            indexMapping.appendArray(withCount: field.count)
        }
    }

    deinit {
        parentConnection!.disconnect()
        fieldConnections.forEach { $0.disconnect() }
    }

    func apply(_ change: ArrayChange<Parent.Element>) {
        precondition(change.initialCount == fieldConnections.count)
        var transformedChange = ArrayChange<Element>(initialCount: indexMapping.postcount)
        for mod in change.modifications {
            let preindex = mod.startIndex
            let postindex = indexMapping.postindex(for: preindex)
            let oldFields = mod.oldElements.map { key($0) }
            let newFields = mod.newElements.map { key($0) }

            // Replace field connections.
            let prerange: Range<Int> = preindex ..< preindex + oldFields.count
            self.fieldConnections.forEach(range: prerange) { $0.disconnect() }
            self.fieldConnections.replaceSubrange(prerange, with: newFields.map { self.connectField($0) })

            // Update index mapping.
            indexMapping.replaceArrays(in: prerange, withCounts: newFields.map { $0.count })

            // Create new change component.
            let oldValues = oldFields.flatMap { $0.value }
            let newValues = newFields.flatMap { $0.value }
            if let mod = ArrayModification(replacing: oldValues, at: postindex, with: newValues) {
                transformedChange.add(mod)
            }
        }
        precondition(change.finalCount == fieldConnections.count)
        if !transformedChange.isEmpty {
            signal.send(transformedChange)
        }
    }

    private func connectField(_ field: Field) -> Connection {
        var connection: Connection? = nil
        connection = field.changes.connect { [unowned self] change in self.apply(change, from: connection!) }
        return connection!
    }

    private func apply(_ change: ArrayChange<Field.Element>, from connection: Connection) {
        let preindex = fieldConnections.index(of: connection)!
        let postindex = indexMapping.postindex(for: preindex)
        let transformedChange = change.widen(startIndex: postindex, initialCount: indexMapping.postcount)
        indexMapping.setCount(forArrayAt: preindex, from: change.initialCount, to: change.finalCount)
        signal.send(transformedChange)
    }

    override var isBuffered: Bool {
        return false
    }

    override subscript(index: Int) -> Element {
        let (preindex, offset) = indexMapping.preindex(for: index)
        return key(parent[preindex])[offset]
    }

    override subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        let start = indexMapping.preindex(for: bounds.lowerBound)
        let end = indexMapping.preindex(for: bounds.upperBound)

        if start.preindex == end.preindex {
            return key(parent[start.preindex])[start.offset ..< end.offset]
        }
        var result: [Element] = []
        result.reserveCapacity(bounds.count)

        let firstField = key(parent[start.preindex])
        result.append(contentsOf: firstField[start.offset ..< firstField.count])

        for i in start.preindex + 1 ..< end.preindex {
            result.append(contentsOf: key(parent[i]).value)
        }

        let lastField = key(parent[end.preindex])
        result.append(contentsOf: lastField[0 ..< end.offset])

        precondition(result.count == bounds.count)
        return ArraySlice(result)
    }

    override var value: Array<Element> {
        return parent.value.flatMap { key($0).value }
    }

    override var count: Int {
        return indexMapping.postcount
    }

    override var changes: Source<Change> { return signal.with(retained: self).source }
}
