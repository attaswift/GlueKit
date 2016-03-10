//
//  SelectEach.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-10.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableArrayType where Index == Int, SubSequence: SequenceType, SubSequence.Generator.Element == Generator.Element {
    public func selectCount() -> Observable<Int> {
        return observableCount
    }
}

extension ObservableArrayType where Index == Int, SubSequence: SequenceType, SubSequence.Generator.Element == Generator.Element {
    public func selectEach<Field: ObservableType>(key: Generator.Element->Field) -> ObservableArray<Field.Value> {
        return ObservableArray<Field.Value>(
            count: { self.count },
            lookup: { range in self[range].map { key($0).value } },
            futureChanges: { ArraySelectorForObservableField(parent: self.observableArray, key: key).source })
    }
}

/// A source for selecting an observable field from an observable array. This is suitable for use in a
/// It sends array changes whenever the parent's contents change or one of the fields updates its value.
///
/// It keeps track of the current index of each field, and updates this mapping whenever something
/// changes in the parent.
private final class ArraySelectorForObservableField<Element, Field: ObservableType>
: SignalDelegate {
    typealias Value = ArrayChange<Field.Value>

    private let parent: ObservableArray<Element>
    private let key: Element->Field

    private var signal = OwningSignal<Value, ArraySelectorForObservableField<Element, Field>>()

    private var parentConnection: Connection? = nil
    private var fieldConnections: [Connection] = []
    private var fieldIndices: [Int: Int] = [:] // ID -> Index
    private var _nextFieldID: Int = 0

    init(parent: ObservableArray<Element>, key: Element->Field) {
        self.parent = parent
        self.key = key
    }

    var source: Source<Value> { return signal.with(self).source }

    func start(signal: Signal<Value>) {
        assert(parentConnection == nil && fieldConnections.isEmpty)
        let fields = parent.value.map(key)
        fieldConnections = fields.enumerate().map { index, field in
            self.connectField(field, index: index, signal: signal)
        }
        parentConnection = parent.futureChanges.connect { change in
            self.applyParentChange(change, signal: signal)
        }
    }

    func stop(signal: Signal<Value>) {
        assert(parentConnection != nil)
        parentConnection?.disconnect()
        fieldConnections.forEach { $0.disconnect() }
        parentConnection = nil
        fieldConnections.removeAll()
        fieldIndices.removeAll()
    }

    private func connectField(field: Field, index: Int, signal: Signal<Value>) -> Connection {
        let id = self.nextFieldID
        self.fieldIndices[id] = index
        let c = field.futureValues.connect { value in self.sendValue(value, forFieldWithID: id, toSignal: signal) }
        c.addCallback { _ in self.fieldIndices[id] = nil }
        return c
    }

    private var nextFieldID: Int {
        var result = _nextFieldID
        repeat {
            result = _nextFieldID
            _nextFieldID = _nextFieldID &+ 1
        } while fieldIndices[result] != nil

        return result
    }
    
    private func sendValue(value: Field.Value, forFieldWithID id: Int, toSignal signal: Signal<Value>) {
        let index = fieldIndices[id]!
        let mod = ArrayModification<Field.Value>.ReplaceAt(index, with: value)
        let change = ArrayChange<Field.Value>(initialCount: self.fieldConnections.count, modification: mod)
        signal.send(change)
    }

    private func applyParentChange(change: ArrayChange<Element>, signal: Signal<Value>) {
        assert(fieldConnections.count == change.initialCount)
        for mod in change.modifications {
            let range = mod.range
            let delta = mod.deltaCount
            let startIndex = range.startIndex
            self.fieldConnections[range].forEach { $0.disconnect() }
            let newConnections = mod.elements.enumerate().map { i, pv in
                self.connectField(self.key(pv), index: startIndex + i, signal: signal)
            }
            self.fieldIndices.forEach { id, index in
                if index >= range.endIndex {
                    self.fieldIndices[id] = index + delta
                }
            }
            self.fieldConnections.replaceRange(range, with: newConnections)

        }
        signal.send(change.map { self.key($0).value })
    }
}

extension ObservableArrayType where Index == Int, Change == ArrayChange<Generator.Element> {
        // Concatenation
    public func selectEach<Field: ObservableArrayType
        where Field.Index == Int, Field.Change == ArrayChange<Field.Generator.Element>, Field.SubSequence.Generator.Element == Field.Generator.Element>
        (key: Generator.Element->Field) -> ObservableArray<Field.Generator.Element> {
        let selector = ArraySelectorForArrayField<Generator.Element, Field>(parent: self.observableArray, key: key)
        return ObservableArray<Field.Generator.Element>(
            count: { selector.count },
            lookup: selector.lookup,
            futureChanges: { selector.changeSource })
    }
}

private final class ArraySelectorForArrayField<ParentElement, Field: ObservableArrayType where Field.Index == Int, Field.Change == ArrayChange<Field.Generator.Element>, Field.SubSequence.Generator.Element == Field.Generator.Element>
: SignalDelegate {
    typealias FieldElement = Field.Generator.Element
    typealias Change = ArrayChange<FieldElement>

    private let parent: ObservableArray<ParentElement>
    private let key: ParentElement->Field

    private var signal = OwningSignal<Change, ArraySelectorForArrayField<ParentElement, Field>>()

    private var active = false
    private var parentConnection: Connection? = nil
    private var fieldConnections: [Connection] = []
    private var startIndexes: [Int] = [0] // This always has an extra element at the end with the count of all elements
    private var fieldIndexByFieldID: [Int: Int] = [:]
    private var _nextFieldID: Int = 0

    init(parent: ObservableArray<ParentElement>, key: ParentElement->Field) {
        self.parent = parent
        self.key = key
    }

    var count: Int {
        if active {
            return startIndexes.last!
        }
        else {
            return parent.reduce(0) { c, pe in c + self.key(pe).count }
        }
    }

    func lookup(range: Range<Int>) -> [FieldElement] {
        var result: [FieldElement] = []
        result.reserveCapacity(range.count)
        var startIndex: Int = 0
        for pe in parent {
            let field = key(pe)
            let endIndex = startIndex + field.count

            let start = max(startIndex, range.startIndex) - startIndex
            let end = min(endIndex, range.endIndex) - startIndex

            if start < end {
                // The range of this element intersects with the lookup range.
                result.appendContentsOf(field[start..<end])
            }
            else if start > end {
                // This element starts after the lookup range ends. We're done.
                return result
            }

            startIndex += field.count
        }
        return result
    }

    var changeSource: Source<Change> { return signal.with(self).source }

    func start(signal: Signal<Change>) {
        assert(active == false)
        assert(parentConnection == nil && fieldConnections.isEmpty)
        let fields = parent.value.map(key)
        startIndexes = [0]
        var start = 0
        fieldConnections = fields.enumerate().map { index, field in
            let c = connectField(field, fieldIndex:index, signal: signal)
            start += field.count
            startIndexes.append(start)
            return c
        }
        parentConnection = parent.futureChanges.connect { change in
            self.applyParentChange(change, signal: signal)
        }
        active = true
    }

    func stop(signal: Signal<Change>) {
        assert(parentConnection != nil)
        parentConnection?.disconnect()
        fieldConnections.forEach { $0.disconnect() }
        parentConnection = nil
        fieldConnections.removeAll()
        startIndexes.removeAll()
        fieldIndexByFieldID.removeAll()
        active = false
    }

    private func connectField(field: Field, fieldIndex: Int, signal: Signal<Change>) -> Connection {
        let id = self.nextFieldID
        self.fieldIndexByFieldID[id] = fieldIndex
        let c = field.futureChanges.connect { change in self.applyFieldChange(change, id: id, signal: signal) }
        c.addCallback { [unowned self] _ in self.fieldIndexByFieldID[id] = nil }
        return c
    }

    private var nextFieldID: Int {
        var result = _nextFieldID
        repeat {
            result = _nextFieldID
            _nextFieldID = _nextFieldID &+ 1
        } while fieldIndexByFieldID[result] != nil

        return result
    }

    private func applyFieldChange(change: ArrayChange<FieldElement>, id: Int, signal: Signal<Change>) {
        let fieldIndex = fieldIndexByFieldID[id]!
        let startIndex = startIndexes[fieldIndex]
        let widenedChange = change.widen(startIndex, count: startIndexes.last!)
        let deltaCount = change.deltaCount
        if deltaCount != 0 {
            adjustIndicesAfter(startIndex, by: deltaCount)
        }
        signal.send(widenedChange)
    }

    private func adjustIndicesAfter(startIndex: Int, by delta: Int) {
        for index in (startIndex + 1)..<startIndexes.count {
            startIndexes[index] += delta
        }
    }

    private func applyParentChange(change: ArrayChange<ParentElement>, signal: Signal<Change>) {
        assert(fieldConnections.count == change.initialCount)
        var result = ArrayChange<FieldElement>(initialCount: startIndexes.last!, modifications: [])
        for mod in change.modifications {
            let fieldRange = mod.range
            let newFields = mod.elements.map { self.key($0) }

            // Replace field connections.
            self.fieldConnections[fieldRange].forEach { $0.disconnect() }
            let newConnections = newFields.enumerate().map { i, field in
                self.connectField(field, fieldIndex: fieldRange.startIndex + i, signal: signal)
            }
            self.fieldConnections.replaceRange(fieldRange, with: newConnections)

            // Update start indexes.
            let oldFieldIndexRange = startIndexes[fieldRange.startIndex] ..< startIndexes[fieldRange.endIndex]
            var newFieldIndexRange = oldFieldIndexRange.startIndex ..< oldFieldIndexRange.startIndex
            let newIndexes: [Int] = newFields.map { field in
                let start = newFieldIndexRange.endIndex
                newFieldIndexRange.endIndex += field.count
                return start
            }
            let deltaCount = newFieldIndexRange.count - oldFieldIndexRange.count
            if deltaCount != 0 {
                for fieldIndex in fieldRange.endIndex..<self.startIndexes.count {
                    startIndexes[fieldIndex] += deltaCount
                }
            }
            self.startIndexes.replaceRange(fieldRange, with: newIndexes)

            // Collect new values.
            var fieldValues: [FieldElement] = []
            for field in newFields {
                fieldValues.appendContentsOf(field)
            }

            // Create new change component.
            if fieldRange.count > 0 || fieldValues.count > 0 {
                result.addModification(ArrayModification(range: oldFieldIndexRange, elements: fieldValues))
            }
        }
        signal.send(result)
    }
}

