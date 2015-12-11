//
//  SelectEach.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-10.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation


/// A source for selecting an observable field from an observable array. This is suitable for use in a
/// It sends array changes whenever the parent's contents change or one of the fields updates its value.
///
/// It keeps track of the current index of each field, and updates this mapping whenever something
/// changes in the parent.
private final class ChangeSourceForObservableFieldInArray<Element, Field: ObservableType>
: SignalDelegate {
    typealias Value = ArrayChange<Field.Value>

    private let parent: ObservableArray<Element>
    private let key: Element->Field

    private lazy var signal: OwningSignal<Value,ChangeSourceForObservableFieldInArray<Element, Field>> = { OwningSignal(delegate: self) }()

    private var parentConnection: Connection? = nil
    private var fieldConnections: [Connection] = []
    private var fieldIndices: [Int: Int] = [:] // ID -> Index
    private var _nextFieldID: Int = 0

    init(parent: ObservableArray<Element>, key: Element->Field) {
        self.parent = parent
        self.key = key
    }

    var source: Source<Value> { return signal.source }

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
        let change = ArrayChange<Field.Value>(count: self.fieldConnections.count, modification: mod)
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
        assert(fieldConnections.count == change.finalCount)
        signal.send(change.map { self.key($0).value })
    }
}

extension ObservableArrayType where Index == Int, SubSequence: SequenceType, SubSequence.Generator.Element == Generator.Element {
    public func selectEach<Field: ObservableType>(key: Generator.Element->Field) -> ObservableArray<Field.Value> {
        return ObservableArray<Field.Value>(
            count: { self.count },
            lookup: { range in self[range].map { key($0).value } },
            futureChanges: { ChangeSourceForObservableFieldInArray(parent: self.observableArray, key: key).source })
    }

    public func selectCount() -> Observable<Int> {
        return observableCount
    }

//    // Concatenation
//    public func selectEach<Field: ObservableArrayType>(key: Generator.Element->Field) -> ObservableArray<Field.Generator.Element> {
//        return ObservableArray<Field.Generator.Element>(
//            count: { self.count },
//            lookup: { range in self[range].map { key($0).value } },
//            futureChanges: { ChangeSourceForObservableFieldInArray(parent: self.observableArray, key: key).source })
//    }

}
