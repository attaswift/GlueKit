//
//  ArrayMappingForArrayField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import BTree

extension ObservableArrayType {
    public func flatMap<Field: ObservableArrayType>(_ key: @escaping (Element) -> Field) -> ObservableArray<Field.Element> {
        let selector = ArrayMappingForArrayField<Self, Field>(parent: self, key: key)
        return selector.observableArray
    }
}

/// Maintains an index mapping for an operation mapping an array of arrays into a single flat array.
///
/// Terminology:
/// - preindex, precount refers to indices/count of the original array of arrays.
/// - postindex, postcount refers to indices/count of the resulting flat array.
private struct Indexmap {
    // TODO: A weight-augmented tree-backed list would work much better here.

    // The ith element in this sorted bag gives us the starting postindex of the source array corresponding to preindex i.
    // The bag always ends with an extra element with the overall count of elements.
    private var postindices: SortedBag<Int> = [0]

    var precount: Int { return postindices.count - 1 }
    var postcount: Int { return postindices.last! }

    func preindex(for postindex: Int) -> (preindex: Int, offset: Int) {
        let p = postindices.highestIndex(notAbove: postindex)!
        let start = postindices[p]
        let preindex = postindices.offset(of: p)
        return (preindex, postindex - start)
    }

    func postindex(for preindex: Int) -> Int {
        return postindices[preindex]
    }

    mutating func appendArray(withCount count: Int) {
        postindices.insert(postcount + count)
    }

    mutating func replaceArrays(in prerange: Range<Int>, withCounts counts: [Int]) {
        let postrange: Range<Int> = postindex(for: prerange.lowerBound) ..< postindex(for: prerange.upperBound)
        let postdelta = counts.reduce(0, +) - postrange.count
        for i in CountableRange(prerange).reversed() { // TODO: SortedBag.remove(offsetsIn: prerange)
            postindices.remove(atOffset: i)
        }
        postindices.shift(startingAt: postindices.index(ofOffset: prerange.lowerBound), by: postdelta)

        var poststart = postrange.lowerBound
        for i in 0 ..< counts.count {
            let count = counts[i]
            postindices.insert(poststart)
            poststart += count
        }
    }

    mutating func setCount(forArrayAt preindex: Int, from old: Int, to new: Int) {
        if old == new { return }
        var i = postindices.index(ofOffset: preindex)
        postindices.formIndex(after: &i)
        postindices.shift(startingAt: i, by: new - old)
    }
}

private final class ArrayMappingForArrayField<Parent: ObservableArrayType, Field: ObservableArrayType>: ObservableArrayBase<Field.Element> {
    typealias Element = Field.Element

    private let parent: Parent
    private let key: (Parent.Element) -> Field

    private var state = TransactionState<Change>()

    private var parentConnection: Connection? = nil
    private var fieldConnections = RefList<Connection>([])
    private var indexMapping = Indexmap()

    init(parent: Parent, key: @escaping (Parent.Element) -> Field) {
        self.parent = parent
        self.key = key
        super.init()

        parentConnection = parent.updates.connect { [unowned self] update in self.apply(update) }
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

    func apply(_ update: ArrayUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            state.begin()
        case .change(let change):
            precondition(change.initialCount == fieldConnections.count)
            var transformedChange = ArrayChange<Element>(initialCount: indexMapping.postcount)
            for mod in change.modifications {
                let preindex = mod.startIndex
                let postindex = indexMapping.postindex(for: preindex)
                let oldFields = mod.oldElements.map { key($0) }
                let newFields = mod.newElements.map { key($0) }

                // Replace field connections.
                let prerange: Range<Int> = preindex ..< preindex + oldFields.count
                self.fieldConnections.forEach(in: prerange) { $0.disconnect() }
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
                state.send(transformedChange)
            }
        case .endTransaction:
            state.end()
        }
    }

    private func connectField(_ field: Field) -> Connection {
        var connection: Connection? = nil
        connection = field.updates.connect { [unowned self] update in self.apply(update, from: connection) }
        return connection!
    }

    private func apply(_ update: ArrayUpdate<Field.Element>, from connection: Connection?) {
        switch update {
        case .beginTransaction:
            state.begin()
        case .change(let change):
            let preindex = fieldConnections.index(of: connection!)!
            let postindex = indexMapping.postindex(for: preindex)
            let transformedChange = change.widen(startIndex: postindex, initialCount: indexMapping.postcount)
            indexMapping.setCount(forArrayAt: preindex, from: change.initialCount, to: change.finalCount)
            state.send(transformedChange)
        case .endTransaction:
            state.end()
        }
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
    
    override var updates: ArrayUpdateSource<Element> { return state.source(retaining: self) }
}
