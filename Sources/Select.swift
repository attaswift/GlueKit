//
//  SelectOperator.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-06.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableValueType {
    /// Map is an operator that implements key path coding and observing.
    /// Given an observable parent and a key that selects a child component (a.k.a "field") of its value that is a source,
    /// `map` returns a new source that can be used connect to the field indirectly through the parent.
    ///
    /// - Parameter key: An accessor function that returns a component of self (a field) that is a SourceType.
    ///
    /// - Returns: A new source that sends the same values as the current source returned by key in the parent.
    public func map<S: SourceType>(_ key: @escaping (Value) -> S) -> Source<S.SourceValue> {
        return ValueMappingForSourceField(parent: self, key: key).source
    }
}

/// A source of values for a Source field.
private final class ValueMappingForSourceField<Parent: ObservableValueType, Field: SourceType>: SignalDelegate, SourceType {
    typealias Value = Field.SourceValue

    let parent: Parent
    let key: (Parent.Value) -> Field

    var signal = OwningSignal<Value>()
    var fieldConnection: Connection? = nil
    var parentConnection: Connection? = nil

    func connect(_ sink: Sink<Value>) -> Connection { return signal.with(self).connect(sink) }

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self.parent = parent
        self.key = key
    }

    func start(_ signal: Signal<Value>) {
        assert(parentConnection == nil)
        let field = key(parent.value)
        parentConnection = parent.changes.connect { [unowned self] change in self.apply(change) }
        fieldConnection = field.connect(signal)
    }

    func stop(_ signal: Signal<Value>) {
        fieldConnection!.disconnect()
        parentConnection!.disconnect()
        fieldConnection = nil
        parentConnection = nil
    }

    private func apply(_ change: SimpleChange<Parent.Value>) {
        let field = key(change.new)
        self.fieldConnection!.disconnect()
        self.fieldConnection = field.connect(signal.with(self))
    }
}

extension ObservableValueType {
    /// Map is an operator that implements key path coding and observing.
    /// Given an observable parent and a key that selects an observable child component (a.k.a "field") of its value,
    /// `map` returns a new observable that can be used to look up and modify the field and observe its changes
    /// indirectly through the parent.
    ///
    /// @param key: An accessor function that returns a component of self (a field) that is itself observable.
    /// @returns A new observable that tracks changes to both self and the field returned by `key`.
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
    ///     let newMessages: Source<Message>
    ///     let messages: ArrayVariable<Message>
    /// }
    /// let currentRoom: Variable<Room>
    /// ```
    ///
    /// You can create an observable for the latest message in the current room with
    /// ```Swift
    /// let observable = currentRoom.map{$0.latestMessage}
    /// ```
    /// Sinks connected to `observable.futureValues` will fire whenever the current room changes, or when a new
    /// message is posted in the current room. The observable can also be used to simply retrieve the latest
    /// message at any time.
    ///
    public func map<O: ObservableValueType>(_ key: @escaping (Value) -> O) -> Observable<O.Value> {
        return ValueMappingForValueField(parent: self, key: key).observable
    }
}

/// A source of changes for an Observable field.
private final class ValueMappingForValueField<Parent: ObservableValueType, Field: ObservableValueType>: ObservableBoxBase<Field.Value>, SignalDelegate {
    typealias Value = Field.Value

    let parent: Parent
    let key: (Parent.Value) -> Field

    private var signal = OwningSignal<SimpleChange<Value>>()
    fileprivate var currentValue: Field.Value? = nil
    private var parentConnection: Connection? = nil
    private var fieldConnection: Connection? = nil

    override var value: Field.Value {
        if let v = currentValue { return v }
        return key(parent.value).value
    }

    override var changes: Source<SimpleChange<Value>> { return signal.with(self).source }

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self.parent = parent
        self.key = key
    }

    func start(_ signal: Signal<SimpleChange<Value>>) {
        precondition(parentConnection == nil)
        let field = key(parent.value)
        currentValue = field.value
        connect(to: field)
        parentConnection = parent.changes.connect { [unowned self] change in self.apply(change) }
    }

    func stop(_ signal: Signal<SimpleChange<Value>>) {
        precondition(parentConnection != nil)
        fieldConnection?.disconnect()
        parentConnection?.disconnect()
        currentValue = nil
        fieldConnection = nil
        parentConnection = nil
    }

    private func connect(to field: Field) {
        self.fieldConnection?.disconnect()
        fieldConnection = field.changes.connect { [unowned self] change in self.apply(change) }
    }

    private func apply(_ change: SimpleChange<Parent.Value>) {
        let field = self.key(change.new)
        let old = self.currentValue!
        let new = field.value
        self.currentValue = new
        self.connect(to: field)
        signal.send(SimpleChange(from: old, to: new))
    }

    private func apply(_ change: SimpleChange<Field.Value>) {
        self.currentValue = change.new
        self.signal.send(change)
    }
}

extension ObservableValueType {
    /// Map is an operator that implements key path coding and observing.
    /// Given an observable parent and a key that selects an observable child component (a.k.a "field") of its value,
    /// `map` returns a new observable that can be used to look up and modify the field and observe its changes
    /// indirectly through the parent. If the field is updatable, then the result will be, too.
    ///
    /// @param key: An accessor function that returns a component of self (a field) that is itself updatable.
    /// @returns A new updatable that tracks changes to both self and the field returned by `key`.
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
    /// You can create an updatable for the avatar image of the author of the latest message in the current room with
    /// ```Swift
    /// let updatable = currentRoom.map{$0.latestMessage}.map{$0.author}.map{$0.avatar}
    /// ```
    /// Sinks connected to `updatable.futureValues` will fire whenever the current room changes, or when a new message is posted
    /// in the current room, or when the author of that message is changed, or when the current
    /// author changes their avatar. The updatable can also be used to simply retrieve the avatar at any time,
    /// or to update it.
    ///
    public func map<U: UpdatableType>(_ key: @escaping (Value) -> U) -> Updatable<U.Value> {
        return ValueMappingForUpdatableField<Self, U>(parent: self, key: key).updatable
    }
}

private final class ValueMappingForUpdatableField<Parent: ObservableValueType, Field: UpdatableType>: UpdatableBoxBase<Field.Value> {
    private let _observable: ValueMappingForValueField<Parent, Field>

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self._observable = ValueMappingForValueField<Parent, Field>(parent: parent, key: key)
    }

    override var value: Field.Value {
        get {
            return _observable.value
        }
        set {
            _observable.key(_observable.parent.value).value = newValue
        }
    }

    override var changes: Source<SimpleChange<Field.Value>> {
        return _observable.changes
    }
}

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
private final class ChangeSourceForObservableArrayField<Parent: ObservableValueType, Field: ObservableArrayType>: SignalDelegate, SourceType {
    typealias Element = Field.Element
    typealias Base = [Element]
    typealias Change = ArrayChange<Element>

    let parent: Parent
    let key: (Parent.Value) -> Field

    private var signal = OwningSignal<Change>()
    private var parentConnection: Connection? = nil
    private var fieldConnection: Connection? = nil
    private var _field: Field? = nil

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self.parent = parent
        self.key = key
    }

    func connect(_ sink: Sink<ArrayChange<Element>>) -> Connection {
        return signal.with(self).connect(sink)
    }

    fileprivate var field: Field {
        if let field = _field { return field }
        return key(parent.value)
    }

    func start(_ signal: Signal<Change>) {
        precondition(parentConnection == nil)
        let field = key(parent.value)
        self.connect(to: field)
        parentConnection = parent.changes.connect { [unowned self] change in self.apply(change) }
    }

    func stop(_ signal: Signal<Change>) {
        precondition(parentConnection != nil)
        fieldConnection?.disconnect()
        parentConnection?.disconnect()
        fieldConnection = nil
        parentConnection = nil
        _field = nil
    }

    private func connect(to field: Field) {
        _field = field
        fieldConnection?.disconnect()
        fieldConnection = field.changes.connect { [unowned self] in self.signal.send($0) }
    }

    private func apply(_ change: SimpleChange<Parent.Value>) {
        let oldValue = self._field!.value
        let field = self.key(change.new)
        self.connect(to: field)
        signal.send(ArrayChange<Element>(from: oldValue, to: field.value))
    }
}

private class ValueMappingForArrayField<Parent: ObservableValueType, Field: ObservableArrayType>: ObservableArrayBase<Field.Element> {
    typealias Element = Field.Element
    typealias Base = [Element]
    typealias Change = ArrayChange<Element>

    private let _changeSource: ChangeSourceForObservableArrayField<Parent, Field>

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        _changeSource = ChangeSourceForObservableArrayField(parent: parent, key: key)
    }
    var parent: Parent { return _changeSource.parent }
    var key: (Parent.Value) -> Field { return _changeSource.key }
    var field: Field { return _changeSource.field }

    override var isBuffered: Bool { return field.isBuffered }
    override subscript(_ index: Int) -> Element { return field[index] }
    override subscript(_ range: Range<Int>) -> ArraySlice<Element> { return field[range] }
    override var value: Array<Element> { return field.value }
    override var count: Int { return field.count }
    override var observableCount: Observable<Int> { return parent.map { self.key($0).observableCount } }
    override var changes: Source<ArrayChange<Field.Element>> { return _changeSource.source }
}

private class ValueMappingForUpdatableArrayField<Parent: ObservableValueType, Field: UpdatableArrayType>: UpdatableArrayBase<Field.Element> {
    typealias Element = Field.Element
    typealias Base = [Element]
    typealias Change = ArrayChange<Element>

    let _changeSource: ChangeSourceForObservableArrayField<Parent, Field>

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        _changeSource = ChangeSourceForObservableArrayField(parent: parent, key: key)
    }
    var parent: Parent { return _changeSource.parent }
    var key: (Parent.Value) -> Field { return _changeSource.key }
    var field: Field { return _changeSource.field }

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
    override var changes: Source<ArrayChange<Field.Element>> { return _changeSource.source }
    override func apply(_ change: ArrayChange<Field.Element>) { field.apply(change) }
}
