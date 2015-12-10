//
//  SelectOperator.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-06.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A source of values for a Source field.
private final class ValueSourceForSourceField<Parent: ObservableType, Field: SourceType>: SourceType, SignalOwner {
    typealias SourceValue = Field.SourceValue

    let parent: Parent
    let key: Parent.Value -> Field

    var fieldConnection: Connection? = nil
    var parentConnection: Connection? = nil

    var source: Source<SourceValue> { return Signal<SourceValue>(stronglyHeldOwner: self).source }

    init(parent: Parent, key: Parent.Value->Field) {
        self.parent = parent
        self.key = key
    }

    func signalDidStart(signal: Signal<SourceValue>) {
        assert(parentConnection == nil)
        let field = key(parent.value)
        fieldConnection = field.connect(signal)
        parentConnection = parent.futureValues.connect { parentValue in
            let field = self.key(parentValue)
            self.fieldConnection?.disconnect()
            self.fieldConnection = field.connect(signal)
        }
    }

    func signalDidStop(signal: Signal<SourceValue>) {
        assert(parentConnection != nil)
        fieldConnection?.disconnect()
        parentConnection?.disconnect()
        fieldConnection = nil
        parentConnection = nil
    }
}

/// A source of changes for an Observable field.
private final class ValueSourceForObservableField<Parent: ObservableType, Field: ObservableType>: SourceType, SignalOwner {
    typealias Value = Field.Value
    typealias SourceValue = Value

    let parent: Parent
    let key: Parent.Value -> Field

    var currentValue: Field.Value? = nil
    var fieldConnection: Connection? = nil
    var parentConnection: Connection? = nil

    var source: Source<Value> { return Signal<Value>(stronglyHeldOwner: self).source }

    init(parent: Parent, key: Parent.Value->Field) {
        self.parent = parent
        self.key = key
    }

    func signalDidStart(signal: Signal<Value>) {
        assert(parentConnection == nil)
        let field = key(parent.value)
        currentValue = field.value
        fieldConnection = field.futureValues.connect(signal)
        parentConnection = parent.futureValues.connect { parentValue in
            let field = self.key(parentValue)
            self.fieldConnection?.disconnect()
            let fv = field.value
            self.currentValue = fv
            self.fieldConnection = field.futureValues.connect(signal)
            signal.send(fv)
        }
    }

    func signalDidStop(signal: Signal<Value>) {
        assert(parentConnection != nil)
        fieldConnection?.disconnect()
        parentConnection?.disconnect()
        currentValue = nil
        fieldConnection = nil
        parentConnection = nil
    }
}

private final class ChangeSourceForObservableArrayField<Parent: ObservableType, Field: ObservableArrayType where Field.Change == ArrayChange<Field.Generator.Element>, Field.Index == Int, Field.BaseCollection == [Field.Generator.Element]>: SourceType, SignalOwner {
    typealias Element = Field.Generator.Element
    typealias Value = Field.Change
    typealias SourceValue = Value

    let parent: Parent
    let key: Parent.Value -> Field

    var fieldConnection: Connection? = nil
    var parentConnection: Connection? = nil
    var _field: Field? = nil
    var _count: Int = 0

    var source: Source<Value> { return Signal<Value>(stronglyHeldOwner: self).source }

    var field: Field {
        if let field = _field {
            return field
        }
        return key(parent.value)
    }

    var count: Int {
        if parentConnection != nil {
            return _count
        }
        else {
            return field.count
        }
    }

    init(parent: Parent, key: Parent.Value->Field) {
        self.parent = parent
        self.key = key
    }

    func signalDidStart(signal: Signal<Value>) {
        assert(parentConnection == nil)
        let field = key(parent.value)
        self._field = field
        _count = field.count
        fieldConnection = field.futureChanges.connect { change in
            self._count = change.finalCount
            signal.send(change)
        }
        parentConnection = parent.futureValues.connect { parentValue in
            let field = self.key(parentValue)
            self._field = field
            self.fieldConnection?.disconnect()
            self.fieldConnection = field.futureChanges.connect(signal)
            let count = self._count
            self._count = field.count
            let mod = ArrayModification<Element>.ReplaceRange(0..<count, with: field.value)
            signal.send(ArrayChange<Element>(count: count, modification: mod))
        }
    }

    func signalDidStop(signal: Signal<Value>) {
        assert(parentConnection != nil)
        fieldConnection?.disconnect()
        parentConnection?.disconnect()
        fieldConnection = nil
        parentConnection = nil
        _field = nil
    }
}

extension ObservableType {
    /// Select is an operator that implements key path coding and observing.
    /// Given a parent Readable and a key that selects an updatable child component of its value, `select` returns a new
    /// Updatable that can be used to look up, modify and observe changes to the child component indirectly through 
    /// the parent.
    ///
    /// For example, given the model for a hypothetical group chat system below, you can create an updatable for
    /// the avatar image of the author of the latest message in the 'foo' room with
    /// `foo.latestMessage.select { $0.author }.select { $0.avatar }'.
    /// Sink connected to this source will fire whenever a new message is posted in foo, or when the current author changes their
    /// avatar. The updatable can also be used to simply retrieve the avatar at any time, or to update it.
    ///
    /// ```
    /// class Account {
    ///     let name: Variable<String>
    ///     let avatar: Variable<Image>
    /// }
    /// class Message {
    ///     let author: Readable<Account>
    /// }
    /// class Room {
    ///     let latestMessage: Readable<Message>
    /// }
    /// let foo: Room
    /// ```
    ///
    /// @param key: An accessor function that returns a component of self that is itself updatable.
    /// @returns A new updatable that tracks changes to both self and the component returned by `key`.
    public func select<S: SourceType>(key: Value->S) -> Source<S.SourceValue> {
        return ValueSourceForSourceField(parent: self, key: key).source
    }

    public func select<O: ObservableType>(key: Value->O) -> Observable<O.Value> {
            return Observable<O.Value>(
                getter: { key(self.value).value },
                futureValues: { ValueSourceForObservableField(parent: self, key: key).source })
    }

    public func select<U: UpdatableType>(key: Value->U) -> Updatable<U.Value> {
        return Updatable<U.Value>(
            getter: { key(self.value).value },
            setter: { key(self.value).value = $0 },
            futureValues: { ValueSourceForObservableField(parent: self, key: key).source })
    }

    public func select<Element, A: ObservableArrayType
        where A.Generator.Element == Element,
        A.Change == ArrayChange<Element>,
        A.Index == Int,
        A.BaseCollection == [Element],
        A.SubSequence: SequenceType,
        A.SubSequence.Generator.Element == Element>
        (key: Value->A) -> ObservableArray<A.Generator.Element> {
        let source = ChangeSourceForObservableArrayField(parent: self, key: key)
        return ObservableArray<A.Generator.Element>(
            count: { source.count },
            lookup: { range in Array(source.field[range]) },
            futureChanges: { source.source }
        )
    }
}

private final class ChangeSourceForObservableFieldInArray<Element, Field: ObservableType>
    : SourceType, SignalOwner {
    typealias Value = ArrayChange<Field.Value>
    typealias SourceValue = Value

    private let parent: ObservableArray<Element>
    private let key: Element->Field

    init(parent: ObservableArray<Element>, key: Element->Field) {
        self.parent = parent
        self.key = key
    }

    private var parentConnection: Connection? = nil
    private var fieldConnections: [Connection] = []
    private var fieldIndices: [Int: Int] = [:] // ID -> Index

    var source: Source<Value> { return Signal<Value>(stronglyHeldOwner: self).source }

    private var _nextFieldID: Int = 0
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

    private func connectField(field: Field, index: Int, signal: Signal<Value>) -> Connection {
        let id = self.nextFieldID
        self.fieldIndices[id] = index
        let c = field.futureValues.connect { value in self.sendValue(value, forFieldWithID: id, toSignal: signal) }
        c.addCallback { _ in self.fieldIndices[id] = nil }
        return c
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

    func signalDidStart(signal: Signal<Value>) {
        assert(parentConnection == nil && fieldConnections.isEmpty)
        let fields = parent.value.map(key)
        fieldConnections = fields.enumerate().map { index, field in
            self.connectField(field, index: index, signal: signal)
        }
        parentConnection = parent.futureChanges.connect { change in
            self.applyParentChange(change, signal: signal)
        }
    }

    func signalDidStop(signal: Signal<Value>) {
        assert(parentConnection != nil)
        parentConnection?.disconnect()
        fieldConnections.forEach { $0.disconnect() }
        parentConnection = nil
        fieldConnections.removeAll()
    }
}

extension ObservableArrayType where Index == Int, SubSequence: SequenceType, SubSequence.Generator.Element == Generator.Element {

    public func selectEach<Field: ObservableType>(key: Generator.Element->Field) -> ObservableArray<Field.Value> {
        return ObservableArray<Field.Value>(
            count: { self.count },
            lookup: { range in self[range].map { key($0).value } },
            futureChanges: { ChangeSourceForObservableFieldInArray(parent: self.observableArray, key: key).source })
    }
}
