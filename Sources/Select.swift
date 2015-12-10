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
    let key: Parent.Change.Value -> Field

    var fieldConnection: Connection? = nil
    var parentConnection: Connection? = nil

    var source: Source<SourceValue> { return Signal<SourceValue>(stronglyHeldOwner: self).source }

    init(parent: Parent, key: Parent.Change.Value->Field) {
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
private final class ChangeSourceForObservableField<Parent: ObservableType, Field: ObservableType>: SourceType, SignalOwner {
    typealias Value = Field.Change
    typealias SourceValue = Value

    let parent: Parent
    let key: Parent.Change.Value -> Field

    var currentValue: Field.Change.Value? = nil
    var fieldConnection: Connection? = nil
    var parentConnection: Connection? = nil

    var source: Source<Value> { return Signal<Value>(stronglyHeldOwner: self).source }

    init(parent: Parent, key: Parent.Change.Value->Field) {
        self.parent = parent
        self.key = key
    }

    func signalDidStart(signal: Signal<Value>) {
        assert(parentConnection == nil)
        let field = key(parent.value)
        currentValue = field.value
        fieldConnection = field.futureChanges.connect(signal)
        parentConnection = parent.futureValues.connect { parentValue in
            let field = self.key(parentValue)
            self.fieldConnection?.disconnect()
            let previousValue = self.currentValue!
            self.currentValue = field.value
            self.fieldConnection = field.futureChanges.connect(signal)

            let change: Field.Change = Field.Change(from: previousValue, to: self.currentValue!)
            if !change.isNull {
                signal.send(change)
            }
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


extension ObservableType where Change.Value == ObservableValue {
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
    public func select<U: UpdatableType where U.Change == SimpleChange<U.ObservableValue>>
        (key: Change.Value->U) -> Updatable<U.Change.Value> {
        return Updatable<U.ObservableValue>(
            getter: { key(self.value).value },
            setter: { key(self.value).value = $0 },
            futureChanges: { ChangeSourceForObservableField(parent: self, key: key).source })
    }

    public func select<O: ObservableType where O.Change == SimpleChange<O.ObservableValue>>
        (key: Change.Value->O) -> Observable<O.Change.Value> {
        return Observable<O.Change.Value>(
            getter: { key(self.value).value },
            futureChanges: { ChangeSourceForObservableField(parent: self, key: key).source })
    }

    public func select<S: SourceType>(key: ObservableValue->S) -> Source<S.SourceValue> {
        return ValueSourceForSourceField(parent: self, key: key).source
    }
}


private final class ChangeSourceForObservableArrayField<Parent: ObservableType, Field: ObservableType where Parent.Change.Value: _ArrayType>: SourceType, SignalOwner {
    typealias Change = SimpleChange<[Field.Change.Value]>
    typealias SourceValue = Change

    let parent: Parent
    let key: Parent.Change.Value.Generator.Element -> Field

    var currentValue: [Field.Change.Value] = []
    var fieldConnections: [Connection] = []
    var parentConnection: Connection? = nil

    init(parent: Parent, key: Parent.Change.Value.Generator.Element->Field) {
        self.parent = parent
        self.key = key
    }

    var source: Source<SourceValue> { return Signal<SourceValue>(stronglyHeldOwner: self).source }

    func signalDidStart(signal: Signal<SourceValue>) {
        assert(parentConnection == nil)
        let fields = parent.value.map(key)
        currentValue = fields.map { $0.value }
        fieldConnections = fields.enumerate().map { i, field in
            field.futureValues.connect { fv in
                self.currentValue[i] = fv
                signal.send(SimpleChange(self.currentValue))
            }
        }
        parentConnection = parent.futureValues.connect { parentValue in
            let fields = parentValue.map(self.key)
            self.fieldConnections.forEach { $0.disconnect() }
            self.currentValue = fields.map { $0.value }
            self.fieldConnections = fields.enumerate().map { i, field in
                field.futureValues.connect { fv in
                    self.currentValue[i] = fv
                    signal.send(SimpleChange(self.currentValue))
                }
            }
            signal.send(SimpleChange(self.currentValue))
        }
    }

    func signalDidStop(signal: Signal<SourceValue>) {
        assert(parentConnection != nil)
        parentConnection?.disconnect()
        fieldConnections.forEach { $0.disconnect() }
        currentValue.removeAll()
        parentConnection = nil
        fieldConnections.removeAll()
    }
}

extension ObservableType where ObservableValue == Change.Value, ObservableValue: _ArrayType {
    public func selectEach<O: ObservableType where O.ObservableValue == O.Change.Value>
        (key: ObservableValue.Generator.Element->O) -> Observable<[O.ObservableValue]> {
        return Observable<[O.ObservableValue]>(
            getter: { self.value.map { key($0).value } },
            futureChanges: { ChangeSourceForObservableArrayField(parent: self, key: key).source })
    }
}

