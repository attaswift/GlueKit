//
//  ValueMappingForSetField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension ObservableValueType {
    public func map<Field: ObservableSetType>(_ key: @escaping (Value) -> Field) -> AnyObservableSet<Field.Element> {
        return ValueMappingForSetField<Self, Field>(parent: self, key: key).anyObservableSet
    }

    public func map<Field: UpdatableSetType>(_ key: @escaping (Value) -> Field) -> AnyUpdatableSet<Field.Element> {
        return ValueMappingForUpdatableSetField<Self, Field>(parent: self, key: key).anyUpdatableSet
    }
}

private final class UpdateSourceForSetField<Parent: ObservableValueType, Field: ObservableSetType>: TransactionalSource<SetChange<Field.Element>> {
    typealias Element = Field.Element
    typealias Change = SetChange<Element>
    typealias Value = Update<Change>

    private struct ParentSink: OwnedSink {
        typealias Owner = UpdateSourceForSetField

        unowned let owner: Owner
        let identifier = 1

        func receive(_ update: ValueUpdate<Parent.Value>) {
            owner.applyParentUpdate(update)
        }
    }

    private struct FieldSink: OwnedSink {
        typealias Owner = UpdateSourceForSetField

        unowned let owner: Owner
        let identifier = 2

        func receive(_ update: SetUpdate<Field.Element>) {
            owner.applyFieldUpdate(update)
        }
    }


    let parent: Parent
    let key: (Parent.Value) -> Field

    private var _field: Field? = nil

    init(parent: Parent, key: @escaping (Parent.Value) -> Field) {
        self.parent = parent
        self.key = key
    }

    fileprivate var field: Field {
        if let field = self._field { return field }
        return key(parent.value)
    }

    override func activate() {
        let field = key(parent.value)
        field.add(FieldSink(owner: self))
        parent.add(ParentSink(owner: self))
        _field = field
    }

    override func deactivate() {
        parent.remove(ParentSink(owner: self))
        _field!.remove(FieldSink(owner: self))
        _field = nil
    }

    private func subscribe(to field: Field) {
        _field!.remove(FieldSink(owner: self))
        _field = field
        field.add(FieldSink(owner: self))
    }

    func applyParentUpdate(_ update: ValueUpdate<Parent.Value>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            let oldValue = self._field!.value
            let field = self.key(change.new)
            self.subscribe(to: field)
            sendChange(SetChange(removed: oldValue, inserted: field.value))
        case .endTransaction:
            endTransaction()
        }
    }

    func applyFieldUpdate(_ update: SetUpdate<Field.Element>) {
        send(update)
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

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        updateSource.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return updateSource.remove(sink)
    }
}

private final class ValueMappingForUpdatableSetField<Parent: ObservableValueType, Field: UpdatableSetType>: _AbstractUpdatableSet<Field.Element> {
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

    override func apply(_ update: SetUpdate<Element>) { field.apply(update) }

    override func remove(_ member: Element) { field.remove(member) }
    override func insert(_ member: Element) { field.insert(member) }
    override func removeAll() { field.removeAll() }
    override func formUnion(_ other: Set<Field.Element>) { field.formUnion(other) }
    override func formIntersection(_ other: Set<Field.Element>) { field.formIntersection(other) }
    override func formSymmetricDifference(_ other: Set<Field.Element>) { field.formSymmetricDifference(other) }
    override func subtract(_ other: Set<Field.Element>) { field.subtract(other) }

    final override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        updateSource.add(sink)
    }

    @discardableResult
    final override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return updateSource.remove(sink)
    }
}
