//
//  SelectOperator.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-06.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A source of values for a Source field.
private final class ValueSelectorForSourceField<Parent: ObservableType, Field: SourceType>: SignalDelegate {
    typealias Value = Field.SourceValue

    let parent: Parent
    let key: Parent.Value -> Field

    lazy var signal: OwningSignal<Value, ValueSelectorForSourceField<Parent, Field>> = { OwningSignal(delegate: self) }()
    var fieldConnection: Connection? = nil
    var parentConnection: Connection? = nil

    var source: Source<Value> { return signal.source }

    init(parent: Parent, key: Parent.Value->Field) {
        self.parent = parent
        self.key = key
    }

    func start(signal: Signal<Value>) {
        assert(parentConnection == nil)
        let field = key(parent.value)
        fieldConnection = field.connect(signal)
        parentConnection = parent.futureValues.connect { parentValue in
            let field = self.key(parentValue)
            self.fieldConnection?.disconnect()
            self.fieldConnection = field.connect(signal)
        }
    }

    func stop(signal: Signal<Value>) {
        assert(parentConnection != nil)
        fieldConnection?.disconnect()
        parentConnection?.disconnect()
        fieldConnection = nil
        parentConnection = nil
    }
}

/// A source of changes for an Observable field.
private final class ValueSelectorForObservableField<Parent: ObservableType, Field: ObservableType>: SignalDelegate {
    typealias Value = Field.Value
    typealias SourceValue = Value

    let parent: Parent
    let key: Parent.Value -> Field

    lazy var signal: OwningSignal<Value, ValueSelectorForObservableField<Parent, Field>> = { OwningSignal(delegate: self) }()
    var currentValue: Field.Value? = nil
    var fieldConnection: Connection? = nil
    var parentConnection: Connection? = nil

    var source: Source<Value> { return signal.source }

    init(parent: Parent, key: Parent.Value->Field) {
        self.parent = parent
        self.key = key
    }

    func start(signal: Signal<Value>) {
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

    func stop(signal: Signal<Value>) {
        assert(parentConnection != nil)
        fieldConnection?.disconnect()
        parentConnection?.disconnect()
        currentValue = nil
        fieldConnection = nil
        parentConnection = nil
    }
}

/// A source of changes for an ObservableArray field.
private final class ValueSelectorForArrayField<Parent: ObservableType, Field: ObservableArrayType where Field.Change == ArrayChange<Field.Generator.Element>, Field.Index == Int, Field.BaseCollection == [Field.Generator.Element]>: SignalDelegate {
    typealias Element = Field.Generator.Element
    typealias Change = Field.Change
    typealias SourceValue = Change

    let parent: Parent
    let key: Parent.Value -> Field

    lazy var signal: OwningSignal<Change, ValueSelectorForArrayField<Parent, Field>> = { OwningSignal(delegate: self) }()
    var fieldConnection: Connection? = nil
    var parentConnection: Connection? = nil
    var _field: Field? = nil
    var _count: Int = 0

    var changeSource: Source<Change> { return signal.source }

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

    func start(signal: Signal<Change>) {
        assert(parentConnection == nil)
        let field = key(parent.value)
        self._field = field
        _count = field.count
        fieldConnection = field.futureChanges.connect { change in
            self._count = change.initialCount + change.deltaCount
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
            signal.send(ArrayChange<Element>(initialCount: count, modification: mod))
        }
    }

    func stop(signal: Signal<Change>) {
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
    /// Given an observable parent and a key that selects an child component (a.k.a "field") of its value that is a source,
    /// `select` returns a new source that can be used connect to the field indirectly through the parent.
    ///
    /// @param key: An accessor function that returns a component of self (a field) that is a SourceType.
    /// @returns A new source that sends the same values as the current source returned by key in the parent.
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
    ///     let newMessages: Source<Message> /* = latestMessage.futureValues */
    ///     let messages: ArrayVariable<Message>
    /// }
    /// let currentRoom: Variable<Room>
    /// ```
    ///
    /// You can create a source for new messages in the current room with
    /// ```Swift
    /// let source = currentRoom.select{$0.newMessages}
    /// ```
    /// Sinks connected to `source` will fire whenever the current room changes and whenever a new
    /// message is posted in the current room.
    ///
    public func select<S: SourceType>(key: Value->S) -> Source<S.SourceValue> {
        return ValueSelectorForSourceField(parent: self, key: key).source
    }

    /// Select is an operator that implements key path coding and observing.
    /// Given an observable parent and a key that selects an observable child component (a.k.a "field") of its value,
    /// `select` returns a new observable that can be used to look up and modify the field and observe its changes
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
    /// let observable = currentRoom.select{$0.latestMessage}
    /// ```
    /// Sinks connected to `observable.futureValues` will fire whenever the current room changes, or when a new 
    /// message is posted in the current room. The observable can also be used to simply retrieve the latest 
    /// message at any time.
    ///
    public func select<O: ObservableType>(key: Value->O) -> Observable<O.Value> {
            return Observable<O.Value>(
                getter: { key(self.value).value },
                futureValues: { ValueSelectorForObservableField(parent: self, key: key).source })
    }

    /// Select is an operator that implements key path coding and observing.
    /// Given an observable parent and a key that selects an observable child component (a.k.a "field") of its value,
    /// `select` returns a new observable that can be used to look up and modify the field and observe its changes
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
    /// let updatable = currentRoom.select{$0.latestMessage}.select{$0.author}.select{$0.avatar}
    /// ```
    /// Sinks connected to `updatable.futureValues` will fire whenever the current room changes, or when a new message is posted
    /// in the current room, or when the author of that message is changed, or when the current
    /// author changes their avatar. The updatable can also be used to simply retrieve the avatar at any time,
    /// or to update it.
    ///
    public func select<U: UpdatableType>(key: Value->U) -> Updatable<U.Value> {
        return Updatable<U.Value>(
            getter: { key(self.value).value },
            setter: { key(self.value).value = $0 },
            futureValues: { ValueSelectorForObservableField(parent: self, key: key).source })
    }

    /// Select is an operator that implements key path coding and observing.
    /// Given an observable parent and a key that selects an observable child component (a.k.a "field") of its value,
    /// `select` returns a new observable that can be used to look up and modify the field and observe its changes
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
    /// let observable = currentRoom.select{$0.messages}
    /// ```
    /// Sinks connected to `observable.futureChanges` will fire whenever the current room changes, or when the list of
    /// messages is updated in the current room.  The observable can also be used to simply retrieve the list of messages
    /// at any time.
    ///
    public func select<Element, A: ObservableArrayType
        where A.Generator.Element == Element,
        A.Change == ArrayChange<Element>,
        A.Index == Int,
        A.BaseCollection == [Element],
        A.SubSequence: SequenceType,
        A.SubSequence.Generator.Element == Element>
        (key: Value->A) -> ObservableArray<A.Generator.Element> {
        let selector = ValueSelectorForArrayField(parent: self, key: key)
        return ObservableArray<A.Generator.Element>(
            count: { selector.count },
            lookup: { range in Array(selector.field[range]) },
            futureChanges: { selector.changeSource }
        )
    }

    public func select<Element, A: UpdatableArrayType
        where A.Generator.Element == Element,
        A.Change == ArrayChange<Element>,
        A.Index == Int,
        A.BaseCollection == [Element],
        A.SubSequence: SequenceType,
        A.SubSequence.Generator.Element == Element>
        (key: Value->A) -> UpdatableArray<A.Generator.Element> {
            let selector = ValueSelectorForArrayField(parent: self, key: key)
            return UpdatableArray<A.Generator.Element>(
                count: { selector.count },
                lookup: { range in Array(selector.field[range]) },
                store: { range, elements in selector.field.replaceRange(range, with: elements) },
                futureChanges: { selector.changeSource }
            )
    }
}

