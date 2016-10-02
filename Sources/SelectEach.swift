//
//  SelectEach.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-10.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableArrayType {
    /// Return an observable array that consists of the values for the field specified by `key` for each element of this array.
    public func selectEach<Field: ObservableType>(_ key: @escaping (Element) -> Field) -> ObservableArray<Field.Value> {
        return ArraySelectorForObservableField(parent: self.observableArray, key: key).observableArray
    }
}

/// A source for selecting an observable field from an observable array. This is suitable for use in a
/// It sends array changes whenever the parent's contents change or one of the fields updates its value.
///
/// It keeps track of the current index of each field, and updates this mapping whenever something
/// changes in the parent.
private final class ArraySelectorForObservableField<Entity, Field: ObservableType>: ObservableArrayType, SignalDelegate {
    typealias Element = Field.Value
    typealias Base = Array<Element>
    typealias Change = ArrayChange<Element>

    private let parent: ObservableArray<Entity>
    private let key: (Entity) -> Field

    private var _changeSignal = OwningSignal<Change>()

    private var parentConnection: Connection? = nil
    private var fieldConnections: [Connection] = []
    private var _value: [Element] = []
    private var fieldIndices: [Int: Int] = [:] // ID -> Index
    private var _nextFieldID: Int = 0

    init(parent: ObservableArray<Entity>, key: @escaping (Entity) -> Field) {
        self.parent = parent
        self.key = key
    }

    var isBuffered: Bool { return true }

    var value: [Element] {
        if parentConnection != nil {
            return _value
        }
        else {
            return parent.value.map { key($0).value }
        }
    }

    subscript(index: Int) -> Element {
        if parentConnection != nil {
            return _value[index]
        }
        else {
            return key(parent[index]).value
        }
    }

    subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        if parentConnection != nil {
            return _value[bounds]
        }
        else {
            return ArraySlice(parent[bounds].map { key($0).value })
        }
    }

    var count: Int {
        return parent.count
    }

    var changes: Source<Change> { return _changeSignal.with(self).source }

    var observable: Observable<[Element]> {
        return Observable(getter: { self.value },
                          futureValues: { self.changes.map { _ in self.value } })
    }

    var observableCount: Observable<Int> {
        return Observable(getter: { self.parent.count },
                          futureValues: { self.parent.changes.map { $0.finalCount } })
    }

    func start(_ signal: Signal<Change>) {
        assert(parentConnection == nil && fieldConnections.isEmpty)
        let fields = parent.value.map(key)
        _value = fields.map { $0.value }
        fieldConnections = fields.enumerated().map { index, field in
            self.connectField(field, index: index, signal: signal)
        }
        parentConnection = parent.changes.connect { change in
            self.applyParentChange(change, signal: signal)
        }
    }

    func stop(_ signal: Signal<Change>) {
        assert(parentConnection != nil)
        parentConnection?.disconnect()
        fieldConnections.forEach { $0.disconnect() }
        _value = []
        parentConnection = nil
        fieldConnections.removeAll()
        fieldIndices.removeAll()
    }

    private func connectField(_ field: Field, index: Int, signal: Signal<Change>) -> Connection {
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
    
    private func sendValue(_ newValue: Field.Value, forFieldWithID id: Int, toSignal signal: Signal<Change>) {
        let index = fieldIndices[id]!
        let oldValue = value[index]
        _value[index] = newValue
        let mod = ArrayModification<Field.Value>.replace(oldValue, at: index, with: newValue)
        let change = ArrayChange<Field.Value>(initialCount: self.fieldConnections.count, modification: mod)
        signal.send(change)
    }

    private func applyParentChange(_ change: ArrayChange<Entity>, signal: Signal<Change>) {
        assert(fieldConnections.count == change.initialCount)
        assert(_value.count == change.initialCount)
        var newChange = ArrayChange<Element>(initialCount: _value.count)
        for mod in change.modifications {
            let startIndex = mod.startIndex
            let old = mod.oldElements
            let new = mod.newElements
            let delta = new.count - old.count
            let inputRange = startIndex ..< startIndex + old.count
            self.fieldConnections[inputRange].forEach { $0.disconnect() }
            self.fieldIndices.forEach { id, index in
                if index >= startIndex + old.count {
                    self.fieldIndices[id] = index + delta
                }
            }
            let newConnections = new.enumerated().map { i, pv in
                self.connectField(self.key(pv), index: startIndex + i, signal: signal)
            }
            self.fieldConnections.replaceSubrange(inputRange, with: newConnections)

            let newValues = new.map { key($0).value }
            let oldValues = Array(_value[inputRange])
            if let mod = ArrayModification(replacing: oldValues, at: startIndex, with: newValues) {
                newChange.add(mod)
            }
            _value.replaceSubrange(inputRange, with: newValues)
        }
        signal.send(newChange)
    }
}

extension ObservableArrayType {
    // Concatenation
    public func selectEach<Field: ObservableArrayType>(_ key: @escaping (Element) -> Field) -> ObservableArray<Field.Element> {
        let selector = ArraySelectorForArrayField<Element, Field>(parent: self.observableArray, key: key)
        return selector.observableArray
    }
}

private final class ArraySelectorForArrayField<ParentElement, Field: ObservableArrayType>: ObservableArrayType, SignalDelegate {
    typealias Element = FieldElement
    typealias Base = [Element]
    typealias Change = ArrayChange<Element>

    typealias FieldElement = Field.Element

    private let parent: ObservableArray<ParentElement>
    private let key: (ParentElement) -> Field

    private var changeSignal = OwningSignal<Change>()

    private var active = false
    private var parentConnection: Connection? = nil
    private var fields: [Field] = []
    private var fieldConnections: [Connection] = []
    private var startIndices: [Int] = [0] // This always has an extra element at the end with the count of all elements
    private var fieldIndexByFieldID: [Int: Int] = [:]
    private var _nextFieldID: Int = 0

    init(parent: ObservableArray<ParentElement>, key: @escaping (ParentElement) -> Field) {
        self.parent = parent
        self.key = key
    }

    var isBuffered: Bool {
        return false
    }

    var value: Array<Element> {
        return parent.value.flatMap { key($0).value }
    }

    subscript(index: Int) -> Element {
        return lookup(index ..< index + 1).first!
    }

    subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        return ArraySlice(lookup(bounds))
    }

    var count: Int {
        if self.active {
            return self.startIndices.last!
        }
        else {
            return self.parent.value.reduce(0) { c, pe in c + self.key(pe).count }
        }
    }

    var changes: Source<Change> { return changeSignal.with(self).source }

    var observable: Observable<[Element]> {
        return self.buffered().observable
    }

    func lookup(_ range: Range<Int>) -> [FieldElement] {
        var result: [FieldElement] = []
        result.reserveCapacity(range.count)
        var startIndex: Int = 0
        for pe in parent.value {
            let field = key(pe)
            let endIndex = startIndex + field.count

            let start = max(startIndex, range.lowerBound) - startIndex
            let end = min(endIndex, range.upperBound) - startIndex

            if start < end {
                // The range of this element intersects with the lookup range.
                result.append(contentsOf: field[start..<end])
            }
            else if start > end {
                // This element starts after the lookup range ends. We're done.
                return result
            }

            startIndex += field.count
        }
        return result
    }

    func start(_ signal: Signal<Change>) {
        assert(active == false)
        assert(parentConnection == nil && fieldConnections.isEmpty)
        fields = parent.value.map(key)
        startIndices = [0]
        var start = 0
        fieldConnections = fields.enumerated().map { index, field in
            let c = connectField(field, fieldIndex:index, signal: signal)
            start += field.count
            startIndices.append(start)
            return c
        }
        parentConnection = parent.changes.connect { change in
            self.applyParentChange(change, signal: signal)
        }
        active = true
    }

    func stop(_ signal: Signal<Change>) {
        assert(parentConnection != nil)
        fields = []
        parentConnection?.disconnect()
        fieldConnections.forEach { $0.disconnect() }
        parentConnection = nil
        fieldConnections.removeAll()
        startIndices.removeAll()
        fieldIndexByFieldID.removeAll()
        active = false
    }

    private func connectField(_ field: Field, fieldIndex: Int, signal: Signal<Change>) -> Connection {
        let id = self.nextFieldID
        self.fieldIndexByFieldID[id] = fieldIndex
        let c = field.changes.connect { change in
            self.applyFieldChange(change, id: id, signal: signal)
        }
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

    private func applyFieldChange(_ change: ArrayChange<FieldElement>, id: Int, signal: Signal<Change>) {
        let fieldIndex = fieldIndexByFieldID[id]!
        let startIndex = startIndices[fieldIndex]
        let widenedChange = change.widen(startIndex: startIndex, initialCount: startIndices.last!)
        let deltaCount = change.deltaCount
        if deltaCount != 0 {
            adjustIndicesAfter(fieldIndex, by: deltaCount)
        }
        signal.send(widenedChange)
    }

    private func adjustIndicesAfter(_ startIndex: Int, by delta: Int) {
        for index in (startIndex + 1)..<startIndices.count {
            startIndices[index] += delta
        }
    }

    private func applyParentChange(_ change: ArrayChange<ParentElement>, signal: Signal<Change>) {
        assert(fieldConnections.count == change.initialCount)
        assert(fields.count == change.initialCount)
        var result = ArrayChange<FieldElement>(initialCount: startIndices.last!, modifications: [])
        for mod in change.modifications {
            let startIndex = mod.startIndex
            let inputRange = startIndex ..< startIndex + mod.inputCount
            let oldFields = fields[inputRange]
            let newFields = mod.newElements.map { self.key($0) }

            let oldValues = oldFields.flatMap { $0.value }
            let newValues = newFields.flatMap { $0.value }

            // Replace field connections.
            self.fieldConnections[inputRange].forEach { $0.disconnect() }
            let newConnections = newFields.enumerated().map { i, field in
                self.connectField(field, fieldIndex: startIndex + i, signal: signal)
            }
            self.fieldConnections.replaceSubrange(inputRange, with: newConnections)
            self.fields.replaceSubrange(inputRange, with: newFields)

            // Update start indexes.
            let startValueIndex = startIndices[startIndex]
            let oldValueCount = startIndices[inputRange.upperBound] - startValueIndex
            var newValueCount = 0

            let newIndices: [Int] = newFields.map { field in
                let start = startValueIndex + newValueCount
                newValueCount += field.count
                return start
            }
            assert(oldValueCount == oldValues.count)
            assert(newValueCount == newValues.count)
            let deltaCount = newValueCount - oldValueCount
            if deltaCount != 0 {
                for fieldIndex in inputRange.upperBound ..< self.startIndices.count {
                    startIndices[fieldIndex] += deltaCount
                }
            }
            self.startIndices.replaceSubrange(inputRange, with: newIndices)

            // Create new change component.
            if let mod = ArrayModification(replacing: oldValues, at: startValueIndex, with: newValues) {
                result.add(mod)
            }
        }
        signal.send(result)
    }
}
