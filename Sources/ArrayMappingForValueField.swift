//
//  ArrayMappingForValueField.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-10.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension ObservableArrayType {
    /// Return an observable array that consists of the values for the field specified by `key` for each element of this array.
    public func map<Field: ObservableValueType>(_ key: @escaping (Element) -> Field) -> AnyObservableArray<Field.Value> {
        return ArrayMappingForValueField(parent: self, key: key).anyObservableArray
    }
}

private final class ArrayMappingForValueField<Parent: ObservableArrayType, Field: ObservableValueType>: _BaseObservableArray<Field.Value> {
    typealias Element = Field.Value
    typealias Change = ArrayChange<Element>

    private final class FieldSink: SinkType, RefListElement {
        unowned let owner: ArrayMappingForValueField
        let field: Field
        var refListLink = RefListLink<FieldSink>()

        init(owner: ArrayMappingForValueField<Parent, Field>, field: Field) {
            self.owner = owner
            self.field = field
            field.add(self)
        }

        func disconnect() {
            field.remove(self)
        }

        func receive(_ update: ValueUpdate<Field.Value>) {
            owner.applyFieldUpdate(update, from: self)
        }
    }

    private struct ParentSink: UniqueOwnedSink {
        typealias Owner = ArrayMappingForValueField

        unowned let owner: Owner

        func receive(_ update: ArrayUpdate<Parent.Element>) {
            owner.applyParentUpdate(update)
        }
    }

    private let parent: Parent
    private let key: (Parent.Element) -> Field

    private var fieldSinks = RefList<FieldSink>()

    init(parent: Parent, key: @escaping (Parent.Element) -> Field) {
        self.parent = parent
        self.key = key
    }

    override var isBuffered: Bool { return false }

    override subscript(index: Int) -> Element {
        return key(parent[index]).value
    }

    override subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        return ArraySlice(parent[bounds].map { key($0).value })
    }

    override var value: [Element] {
        return parent.value.map { key($0).value }
    }

    override var count: Int { return parent.count }

    override func activate() {
        let fields = parent.value.map(key)
        parent.add(ParentSink(owner: self))
        fieldSinks = RefList(fields.lazy.map { field in FieldSink(owner: self, field: field) })
    }

    override func deactivate() {
        parent.remove(ParentSink(owner: self))
        fieldSinks.forEach { $0.disconnect() }
        fieldSinks.removeAll()
    }

    private func applyFieldUpdate(_ update: ValueUpdate<Element>, from sink: FieldSink) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            let index = fieldSinks.index(of: sink)!
            sendChange(ArrayChange(initialCount: fieldSinks.count,
                                   modification: .replace(change.old, at: index, with: change.new)))
        case .endTransaction:
            endTransaction()
        }
    }

    func applyParentUpdate(_ update: ArrayUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            precondition(fieldSinks.count == change.initialCount)
            var newChange = ArrayChange<Element>(initialCount: change.initialCount)
            for mod in change.modifications {
                let start = mod.startIndex
                var i = start
                mod.forEachOldElement { old in
                    fieldSinks[i].disconnect()
                    i += 1
                }
                var sinks: [FieldSink] = []
                mod.forEachNewElement { new in
                    let field = key(new)
                    sinks.append(FieldSink(owner: self, field: field))
                }
                fieldSinks.replaceSubrange(start ..< i, with: sinks)
                newChange.add(mod.map { self.key($0).value })
            }
            precondition(fieldSinks.count == change.finalCount)
            if !newChange.isEmpty {
                sendChange(newChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }
}
