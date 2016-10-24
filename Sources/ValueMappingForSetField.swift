//
//  ValueMappingForSetField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableValueType {
    public func map<Field: ObservableSetType>(_ key: @escaping (Value) -> Field) -> ObservableSet<Field.Element> {
        return ValueMappingForSetField<Self, Field>(parent: self, key: key).observableSet
    }

    public func map<Field: UpdatableSetType>(_ key: @escaping (Value) -> Field) -> UpdatableSet<Field.Element> {
        return ValueMappingForUpdatableSetField<Self, Field>(parent: self, key: key).updatableSet
    }
}

private final class UpdateSourceForSetField<Parent: ObservableValueType, Field: ObservableSetType>: SignalDelegate {
    typealias Element = Field.Element
    typealias Change = SetChange<Element>

    let parent: Parent
    let key: (Parent.Value) -> Field

    private var state = TransactionState<Change>()
    private var parentConnection: Connection? = nil
    private var fieldConnection: Connection? = nil
    private var _field: Field? = nil

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self.parent = parent
        self.key = key
    }

    var source: Source<Update<Change>> {
        return state.source(retainingDelegate: self).source
    }

    fileprivate var field: Field {
        if let field = self._field { return field }
        return key(parent.value)
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
        _field = nil
    }

    private func connect(to field: Field) {
        _field = field
        fieldConnection?.disconnect()
        fieldConnection = field.updates.connect { [unowned self] in self.apply($0) }
    }

    private func apply(_ update: ValueUpdate<Parent.Value>) {
        switch update {
        case .beginTransaction:
            state.begin()
        case .change(let change):
            let oldValue = self._field!.value
            let field = self.key(change.new)
            self.connect(to: field)
            state.send(SetChange(removed: oldValue, inserted: field.value))
        case .endTransaction:
            state.end()
        }
    }

    private func apply(_ update: SetUpdate<Field.Element>) {
        state.send(update)
    }
}

private final class ValueMappingForSetField<Parent: ObservableValueType, Field: ObservableSetType>: _AbstractObservableSet<Field.Element> {
    typealias Element = Field.Element

    private let updateSource: UpdateSourceForSetField<Parent, Field>

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self.updateSource = .init(parent: parent, key: key)
    }

    var field: Field { return updateSource.field }

    override var isBuffered: Bool { return field.isBuffered }
    override var count: Int { return field.count }
    override var value: Set<Element> { return field.value }
    override func contains(_ member: Element) -> Bool { return field.contains(member) }
    override func isSubset(of other: Set<Element>) -> Bool { return field.isSubset(of: other) }
    override func isSuperset(of other: Set<Element>) -> Bool { return field.isSuperset(of: other) }

    override var updates: SetUpdateSource<Element> { return updateSource.source }
}

private final class ValueMappingForUpdatableSetField<Parent: ObservableValueType, Field: UpdatableSetType>: _AsbtractUpdatableSet<Field.Element> {
    typealias Element = Field.Element

    private let updateSource: UpdateSourceForSetField<Parent, Field>

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self.updateSource = .init(parent: parent, key: key)
    }

    var field: Field { return updateSource.field }

    override var isBuffered: Bool { return field.isBuffered }
    override var count: Int { return field.count }
    override var value: Set<Element> {
        get { return field.value }
        set { field.value = newValue }
    }
    override func contains(_ member: Element) -> Bool { return field.contains(member) }
    override func isSubset(of other: Set<Element>) -> Bool { return field.isSubset(of: other) }
    override func isSuperset(of other: Set<Element>) -> Bool { return field.isSuperset(of: other) }

    override func withTransaction<Result>(_ body: () -> Result) -> Result {
        return field.withTransaction(body)
    }
    override func apply(_ change: SetChange<Element>) { field.apply(change) }

    override func remove(_ member: Element) { field.remove(member) }
    override func insert(_ member: Element) { field.insert(member) }
    override func removeAll() { field.removeAll() }
    override func formUnion(_ other: Set<Field.Element>) { field.formUnion(other) }
    override func formIntersection(_ other: Set<Field.Element>) { field.formIntersection(other) }
    override func formSymmetricDifference(_ other: Set<Field.Element>) { field.formSymmetricDifference(other) }
    override func subtract(_ other: Set<Field.Element>) { field.subtract(other) }

    override var updates: SetUpdateSource<Element> { return updateSource.source }
}
