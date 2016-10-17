//
//  ValueMappingForSetField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableValueType {
    public func map<Field: ObservableSetType>(_ key: @escaping (Value) -> Field) -> ObservableSet<Field.Element> {
        return ValueMappingForSetField<Self, Field>(parent: self, key: key).observableSet
    }

    public func map<Field: UpdatableSetType>(_ key: @escaping (Value) -> Field) -> UpdatableSet<Field.Element> {
        return ValueMappingForUpdatableSetField<Self, Field>(parent: self, key: key).updatableSet
    }
}

private final class ChangeSourceForObservableSetField<Parent: ObservableValueType, Field: ObservableSetType>: SignalDelegate, SourceType {
    typealias Element = Field.Element
    typealias Change = SetChange<Element>

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

    func connect(_ sink: Sink<Change>) -> Connection {
        return signal.with(self).connect(sink)
    }

    fileprivate var field: Field {
        if let field = self._field { return field }
        return key(parent.value)
    }

    func start(_ signal: Signal<Change>) {
        precondition(parentConnection == nil)
        let field = key(parent.value)
        self.connect(to: field)
        parentConnection = parent.changes.connect { [unowned self] change in self.apply(change) }
    }

    func stop(_ signal: Signal<Change>) {
        fieldConnection!.disconnect()
        parentConnection!.disconnect()
        fieldConnection = nil
        parentConnection = nil
        _field = nil
    }

    private func connect(to field: Field) {
        _field = field
        fieldConnection?.disconnect()
        fieldConnection = field.changes.connect { [unowned self] change in self.signal.send(change) }
    }

    private func apply(_ change: ValueChange<Parent.Value>) {
        let oldValue = self._field!.value
        let field = self.key(change.new)
        self.connect(to: field)
        signal.send(SetChange(removed: oldValue, inserted: field.value))
    }
}

private final class ValueMappingForSetField<Parent: ObservableValueType, Field: ObservableSetType>: ObservableSetBase<Field.Element> {
    typealias Element = Field.Element

    private let changeSource: ChangeSourceForObservableSetField<Parent, Field>

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self.changeSource = .init(parent: parent, key: key)
    }

    var field: Field { return changeSource.field }

    override var isBuffered: Bool { return field.isBuffered }
    override var count: Int { return field.count }
    override var value: Set<Element> { return field.value }
    override func contains(_ member: Element) -> Bool { return field.contains(member) }
    override func isSubset(of other: Set<Element>) -> Bool { return field.isSubset(of: other) }
    override func isSuperset(of other: Set<Element>) -> Bool { return field.isSuperset(of: other) }

    override var changes: Source<SetChange<Element>> { return changeSource.source }
}

private final class ValueMappingForUpdatableSetField<Parent: ObservableValueType, Field: UpdatableSetType>: UpdatableSetBase<Field.Element> {
    typealias Element = Field.Element

    private let changeSource: ChangeSourceForObservableSetField<Parent, Field>

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self.changeSource = .init(parent: parent, key: key)
    }

    var field: Field { return changeSource.field }

    override var isBuffered: Bool { return field.isBuffered }
    override var count: Int { return field.count }
    override var value: Set<Element> {
        get { return field.value }
        set { field.value = newValue }
    }
    override func contains(_ member: Element) -> Bool { return field.contains(member) }
    override func isSubset(of other: Set<Element>) -> Bool { return field.isSubset(of: other) }
    override func isSuperset(of other: Set<Element>) -> Bool { return field.isSuperset(of: other) }

    override func apply(_ change: SetChange<Element>) { field.apply(change) }

    override func remove(_ member: Element) { field.remove(member) }
    override func insert(_ member: Element) { field.insert(member) }
    override func removeAll() { field.removeAll() }
    override func formUnion(_ other: Set<Field.Element>) { field.formUnion(other) }
    override func formIntersection(_ other: Set<Field.Element>) { field.formIntersection(other) }
    override func formSymmetricDifference(_ other: Set<Field.Element>) { field.formSymmetricDifference(other) }
    override func subtract(_ other: Set<Field.Element>) { field.subtract(other) }

    override var changes: Source<SetChange<Element>> { return changeSource.source }
}
