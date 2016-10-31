//
//  ValueMappingForArrayField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableValueType where Change == ValueChange<Value> {

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
    ///     let latestMessage: AnyObservableValue<Message>
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
    public func map<Field: ObservableArrayType>(_ key: @escaping (Value) -> Field) -> AnyObservableArray<Field.Element> where Field.Change == ArrayChange<Field.Element> {
        return ValueMappingForArrayField(parent: self, key: key).anyObservableArray
    }

    public func map<Field: UpdatableArrayType>(_ key: @escaping (Value) -> Field) -> AnyUpdatableArray<Field.Element> where Field.Change == ArrayChange<Field.Element> {
        return ValueMappingForUpdatableArrayField(parent: self, key: key).anyUpdatableArray
    }
}

private struct ParentSink<Parent: ObservableValueType, Field: ObservableArrayType>: OwnedSink
where Parent.Change == ValueChange<Parent.Value>, Field.Change == ArrayChange<Field.Element> {
    typealias Owner = UpdateSourceForArrayField<Parent, Field>

    unowned let owner: Owner
    let identifier = 1

    func receive(_ update: ValueUpdate<Parent.Value>) {
        owner.applyParentUpdate(update)
    }
}

private struct FieldSink<Parent: ObservableValueType, Field: ObservableArrayType>: OwnedSink
where Parent.Change == ValueChange<Parent.Value>, Field.Change == ArrayChange<Field.Element> {
    typealias Owner = UpdateSourceForArrayField<Parent, Field>

    unowned let owner: Owner
    let identifier = 2

    func receive(_ update: ArrayUpdate<Field.Element>) {
        owner.applyFieldUpdate(update)
    }
}

/// A source of changes for an AnyObservableArray field.
private final class UpdateSourceForArrayField<Parent: ObservableValueType, Field: ObservableArrayType>
: TransactionalSource<ArrayChange<Field.Element>>
where Parent.Change == ValueChange<Parent.Value>, Field.Change == ArrayChange<Field.Element> {
    typealias Element = Field.Element
    typealias Base = [Element]
    typealias Change = ArrayChange<Element>

    let parent: Parent
    let key: (Parent.Value) -> Field

    private var field: Field? = nil

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self.parent = parent
        self.key = key
    }

    override func activate() {
        let field = key(parent.value)
        parent.add(ParentSink(owner: self))
        field.add(FieldSink(owner: self))
        self.field = field
    }

    override func deactivate() {
        parent.remove(ParentSink(owner: self))
        field!.remove(FieldSink(owner: self))
        field = nil
    }

    func applyParentUpdate(_ update: ValueUpdate<Parent.Value>) {
        switch update {
        case .beginTransaction:
            state.begin()
        case .change(let change):
            let old = key(change.old).value
            let field = self.key(change.new)
            self.field!.remove(FieldSink(owner: self))
            self.field = field
            field.add(FieldSink(owner: self))
            state.send(.init(from: old, to: field.value))
        case .endTransaction:
            state.end()
        }
    }

    func applyFieldUpdate(_ update: ArrayUpdate<Field.Element>) {
        state.send(update)
    }
}

private final class ValueMappingForArrayField<Parent: ObservableValueType, Field: ObservableArrayType>: _AbstractObservableArray<Field.Element>
where Parent.Change == ValueChange<Parent.Value>, Field.Change == ArrayChange<Field.Element> {
    typealias Element = Field.Element
    typealias Change = ArrayChange<Element>

    private let updateSource: UpdateSourceForArrayField<Parent, Field>

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        updateSource = UpdateSourceForArrayField(parent: parent, key: key)
    }
    var parent: Parent { return updateSource.parent }
    var key: (Parent.Value) -> Field { return updateSource.key }
    var field: Field { return updateSource.key(updateSource.parent.value) }

    override var isBuffered: Bool { return field.isBuffered }
    override subscript(_ index: Int) -> Element { return field[index] }
    override subscript(_ range: Range<Int>) -> ArraySlice<Element> { return field[range] }
    override var value: Array<Element> { return field.value }
    override var count: Int { return field.count }
    override var observableCount: AnyObservableValue<Int> { return parent.map { self.key($0).observableCount } }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        updateSource.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return updateSource.remove(sink)
    }
}

private final class ValueMappingForUpdatableArrayField<Parent: ObservableValueType, Field: UpdatableArrayType>: _AbstractUpdatableArray<Field.Element>
where Parent.Change == ValueChange<Parent.Value>, Field.Change == ArrayChange<Field.Element> {
    typealias Element = Field.Element
    typealias Change = ArrayChange<Element>

    let updateSource: UpdateSourceForArrayField<Parent, Field>

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        updateSource = UpdateSourceForArrayField(parent: parent, key: key)
    }
    var parent: Parent { return updateSource.parent }
    var key: (Parent.Value) -> Field { return updateSource.key }
    var field: Field { return updateSource.key(updateSource.parent.value) }

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
    override var observableCount: AnyObservableValue<Int> { return parent.map { self.key($0).observableCount } }
    override func apply(_ update: Update<ArrayChange<Field.Element>>) { field.apply(update) }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        updateSource.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return updateSource.remove(sink)
    }
}
