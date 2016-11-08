//
//  ArrayMappingForArrayField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import BTree

extension ObservableArrayType where Change == ArrayChange<Element> {
    public func flatMap<Field: ObservableArrayType>(_ key: @escaping (Element) -> Field) -> AnyObservableArray<Field.Element> where Field.Change == ArrayChange<Field.Element> {
        return ArrayMappingForArrayField<Self, Field>(parent: self, key: key).anyObservableArray
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
        let p = postindices.indexOfLastElement(notAfter: postindex)!
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

private final class FieldSink<Parent: ObservableArrayType, Field: ObservableArrayType>: SinkType, RefListElement
where Parent.Change == ArrayChange<Parent.Element>, Field.Change == ArrayChange<Field.Element> {
    typealias Owner = ArrayMappingForArrayField<Parent, Field>

    unowned let owner: Owner
    let field: Field
    var refListLink = RefListLink<FieldSink>()

    init(owner: Owner, field: Field) {
        self.owner = owner
        self.field = field
        field.add(self)
    }

    func disconnect() {
        field.remove(self)
    }

    func receive(_ update: ArrayUpdate<Field.Element>) {
        owner.applyFieldUpdate(update, from: self)
    }
}

private struct ParentSink<Parent: ObservableArrayType, Field: ObservableArrayType>: UniqueOwnedSink
where Parent.Change == ArrayChange<Parent.Element>, Field.Change == ArrayChange<Field.Element> {
    typealias Owner = ArrayMappingForArrayField<Parent, Field>

    unowned(unsafe) let owner: Owner

    func receive(_ update: ArrayUpdate<Parent.Element>) {
        owner.applyParentUpdate(update)
    }
}

private final class ArrayMappingForArrayField<Parent: ObservableArrayType, Field: ObservableArrayType>: _BaseObservableArray<Field.Element>
where Parent.Change == ArrayChange<Parent.Element>, Field.Change == ArrayChange<Field.Element> {
    typealias Element = Field.Element

    private let parent: Parent
    private let key: (Parent.Element) -> Field

    private var fieldSinks = RefList<FieldSink<Parent, Field>>()
    private var indexMapping = Indexmap()

    init(parent: Parent, key: @escaping (Parent.Element) -> Field) {
        self.parent = parent
        self.key = key
        super.init()

        parent.updates.add(ParentSink<Parent, Field>(owner: self))
        for pe in parent.value {
            let field = key(pe)
            fieldSinks.append(FieldSink(owner: self, field: field))
            indexMapping.appendArray(withCount: field.count)
        }
    }

    deinit {
        parent.updates.remove(ParentSink<Parent, Field>(owner: self))
        fieldSinks.forEach { $0.disconnect() }
    }

    func applyParentUpdate(_ update: ArrayUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            precondition(change.initialCount == fieldSinks.count)
            var transformedChange = ArrayChange<Element>(initialCount: indexMapping.postcount)
            for mod in change.modifications {
                let preindex = mod.startIndex
                let postindex = indexMapping.postindex(for: preindex)
                let oldFields = mod.oldElements.map { key($0) }
                let newFields = mod.newElements.map { key($0) }

                // Replace field connections.
                let prerange: Range<Int> = preindex ..< preindex + oldFields.count
                self.fieldSinks.forEach(in: prerange) { $0.disconnect() }
                self.fieldSinks.replaceSubrange(prerange, with: newFields.map { FieldSink(owner: self, field: $0) })

                // Update index mapping.
                indexMapping.replaceArrays(in: prerange, withCounts: newFields.map { $0.count })

                // Create new change component.
                let oldValues = oldFields.flatMap { $0.value }
                let newValues = newFields.flatMap { $0.value }
                if let mod = ArrayModification(replacing: oldValues, at: postindex, with: newValues) {
                    transformedChange.add(mod)
                }
            }
            precondition(change.finalCount == fieldSinks.count)
            if !transformedChange.isEmpty {
                sendChange(transformedChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }

    func applyFieldUpdate(_ update: ArrayUpdate<Field.Element>, from sink: FieldSink<Parent, Field>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            let preindex = fieldSinks.index(of: sink)!
            let postindex = indexMapping.postindex(for: preindex)
            let transformedChange = change.widen(startIndex: postindex, initialCount: indexMapping.postcount)
            indexMapping.setCount(forArrayAt: preindex, from: change.initialCount, to: change.finalCount)
            sendChange(transformedChange)
        case .endTransaction:
            endTransaction()
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
}
