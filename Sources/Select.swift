//
//  SelectOperator.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-06.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A source of values for a Source field.
private final class ValueSourceForSourceField<Parent: ObservableType, Field: SourceType>: SignalDelegate {
    typealias Value = Field.SourceValue

    let parent: Parent
    let key: Parent.Value -> Field

    lazy var signal: OwningSignal<Value, ValueSourceForSourceField<Parent, Field>> = { OwningSignal(delegate: self) }()
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
private final class ValueSourceForObservableField<Parent: ObservableType, Field: ObservableType>: SignalDelegate {
    typealias Value = Field.Value
    typealias SourceValue = Value

    let parent: Parent
    let key: Parent.Value -> Field

    lazy var signal: OwningSignal<Value, ValueSourceForObservableField<Parent, Field>> = { OwningSignal(delegate: self) }()
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
private final class ChangeSourceForObservableArrayField<Parent: ObservableType, Field: ObservableArrayType where Field.Change == ArrayChange<Field.Generator.Element>, Field.Index == Int, Field.BaseCollection == [Field.Generator.Element]>: SignalDelegate {
    typealias Element = Field.Generator.Element
    typealias Value = Field.Change
    typealias SourceValue = Value

    let parent: Parent
    let key: Parent.Value -> Field

    lazy var signal: OwningSignal<Value, ChangeSourceForObservableArrayField<Parent, Field>> = { OwningSignal(delegate: self) }()
    var fieldConnection: Connection? = nil
    var parentConnection: Connection? = nil
    var _field: Field? = nil
    var _count: Int = 0

    var source: Source<Value> { return signal.source }

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

    func start(signal: Signal<Value>) {
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

    func stop(signal: Signal<Value>) {
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

    public func select<Element, A: UpdatableArrayType
        where A.Generator.Element == Element,
        A.Change == ArrayChange<Element>,
        A.Index == Int,
        A.BaseCollection == [Element],
        A.SubSequence: SequenceType,
        A.SubSequence.Generator.Element == Element>
        (key: Value->A) -> UpdatableArray<A.Generator.Element> {
            let source = ChangeSourceForObservableArrayField(parent: self, key: key)
            return UpdatableArray<A.Generator.Element>(
                count: { source.count },
                lookup: { range in Array(source.field[range]) },
                store: { range, elements in source.field.replaceRange(range, with: elements) },
                futureChanges: { source.source }
            )
    }
}

