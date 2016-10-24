//
//  ValueMappingForArrayField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableValueType {

    /// Map is an operator that implements key path coding and observing.
    /// Given an observable parent and a key that selects an observable child component (a.k.a "field") of its value,
    /// `map` returns a new observable that can be used to look up and modify the field and observe its changes
    /// indirectly through the parent. If the field is an observable array, then the result will be, too.
    ///
    /// @param key: An accessor function that returns a component of self (a field) that is an observable array.
    /// @returns A new observable array that tracks changes to both self and the field returned by `key`.
    ///
    /// For example, take the model for a hypothetical group chat system below.
    /// ```
    /// class Account {
    ///     let name: Variable<String>
    ///     let avatar: Variable<Image>
    /// }
    /// class Message {
    ///     let author: Variable<Account>
    ///     let text: Variable<String>
    /// }
    /// class Room {
    ///     let latestMessage: Observable<Message>
    ///     let messages: ArrayVariable<Message>
    ///     let newMessages: Source<Message>
    /// }
    /// let currentRoom: Variable<Room>
    /// ```
    ///
    /// You can create an observable array for all messages in the current room with
    /// ```Swift
    /// let observable = currentRoom.map{$0.messages}
    /// ```
    /// Sinks connected to `observable.changes` will fire whenever the current room changes, or when the list of
    /// messages is updated in the current room.  The observable can also be used to simply retrieve the list of messages
    /// at any time.
    ///
    public func map<Field: ObservableArrayType>(_ key: @escaping (Value) -> Field) -> ObservableArray<Field.Element> {
        return ValueMappingForArrayField(parent: self, key: key).observableArray
    }

    public func map<Field: UpdatableArrayType>(_ key: @escaping (Value) -> Field) -> UpdatableArray<Field.Element> {
        return ValueMappingForUpdatableArrayField(parent: self, key: key).updatableArray
    }
}

/// A source of changes for an ObservableArray field.
private final class UpdateSourceForArrayField<Parent: ObservableValueType, Field: ObservableArrayType>
: _AbstractSource<Update<ArrayChange<Field.Element>>>, SignalDelegate {
    typealias Element = Field.Element
    typealias Base = [Element]
    typealias Change = ArrayChange<Element>

    let parent: Parent
    let key: (Parent.Value) -> Field

    private var state = TransactionState<Change>()
    private var parentConnection: Connection? = nil
    private var fieldConnection: Connection? = nil

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self.parent = parent
        self.key = key
    }

    override func connect<S: SinkType>(_ sink: S) -> Connection where S.SinkValue == Update<Change> {
        return state.source(retainingDelegate: self).connect(sink)
    }

    func start(_ signal: Signal<Update<Change>>) {
        precondition(parentConnection == nil)
        let field = key(parent.value)
        self.connect(to: field)
        parentConnection = parent.updates.connect { [unowned self] in self.apply($0) }
    }

    func stop(_ signal: Signal<Update<Change>>) {
        fieldConnection!.disconnect()
        parentConnection!.disconnect()
        fieldConnection = nil
        parentConnection = nil
    }

    private func connect(to field: Field) {
        fieldConnection?.disconnect()
        fieldConnection = field.updates.connect { [unowned self] in self.apply($0) }
    }

    private func apply(_ update: ValueUpdate<Parent.Value>) {
        switch update {
        case .beginTransaction:
            state.begin()
        case .change(let change):
            let old = key(change.old).value
            let field = self.key(change.new)
            state.send(.init(from: old, to: field.value))
            self.connect(to: field)
        case .endTransaction:
            state.end()
        }
    }

    private func apply(_ update: ArrayUpdate<Field.Element>) {
        state.send(update)
    }
}

private class ValueMappingForArrayField<Parent: ObservableValueType, Field: ObservableArrayType>: _AbstractObservableArray<Field.Element> {
    typealias Element = Field.Element
    typealias Base = [Element]
    typealias Change = ArrayChange<Element>

    private let _updateSource: UpdateSourceForArrayField<Parent, Field>

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        _updateSource = UpdateSourceForArrayField(parent: parent, key: key)
    }
    var parent: Parent { return _updateSource.parent }
    var key: (Parent.Value) -> Field { return _updateSource.key }
    var field: Field { return _updateSource.key(_updateSource.parent.value) }

    override var isBuffered: Bool { return field.isBuffered }
    override subscript(_ index: Int) -> Element { return field[index] }
    override subscript(_ range: Range<Int>) -> ArraySlice<Element> { return field[range] }
    override var value: Array<Element> { return field.value }
    override var count: Int { return field.count }
    override var observableCount: Observable<Int> { return parent.map { self.key($0).observableCount } }
    override var updates: ArrayUpdateSource<Element> { return _updateSource.source }
}

private class ValueMappingForUpdatableArrayField<Parent: ObservableValueType, Field: UpdatableArrayType>: _AbstractUpdatableArray<Field.Element> {
    typealias Element = Field.Element
    typealias Base = [Element]
    typealias Change = ArrayChange<Element>

    let _updateSource: UpdateSourceForArrayField<Parent, Field>

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        _updateSource = UpdateSourceForArrayField(parent: parent, key: key)
    }
    var parent: Parent { return _updateSource.parent }
    var key: (Parent.Value) -> Field { return _updateSource.key }
    var field: Field { return _updateSource.key(_updateSource.parent.value) }

    override var isBuffered: Bool { return field.isBuffered }
    override subscript(_ index: Int) -> Element {
        get { return field[index] }
        set { field[index] = newValue }
    }
    override subscript(_ range: Range<Int>) -> ArraySlice<Element> {
        get { return field[range] }
        set { field[range] = newValue }
    }
    override var value: Array<Element> {
        get { return field.value }
        set { field.value = newValue }
    }
    override var count: Int { return field.count }
    override var observableCount: Observable<Int> { return parent.map { self.key($0).observableCount } }
    override var updates: ArrayUpdateSource<Element> { return _updateSource.source }
    override func withTransaction<Result>(_ body: () -> Result) -> Result { return field.withTransaction(body) }
    override func apply(_ change: ArrayChange<Field.Element>) { field.apply(change) }
}
