//
//  SetSortingByMappingToObservableComparable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import BTree

extension ObservableSetType where Element: AnyObject {
    /// Given a transformation into an observable of a comparable type, return an observable array
    /// containing transformed versions of elements in this set, in increasing order.
    public func sorted<Field: ObservableValueType>(by transform: @escaping (Element) -> Field) -> AnyObservableArray<Field.Value> where Field.Value: Comparable {
        return SetSortingByMappingToObservableComparable(parent: self, transform: transform).anyObservableArray
    }
}

private class SetSortingByMappingToObservableComparable<Parent: ObservableSetType, Field: ObservableValueType>: _BaseObservableArray<Field.Value>
where Parent.Element: AnyObject, Field.Value: Comparable {
    typealias Element = Field.Value
    typealias Change = ArrayChange<Element>
    typealias FieldSink = AnySink<ValueUpdate<Element>>

    private let parent: Parent
    private let transform: (Parent.Element) -> Field

    private var contents: Map<Element, Int> = [:]
    private var fields: Dictionary<FieldSink, Field> = [:]

    init(parent: Parent, transform: @escaping (Parent.Element) -> Field) {
        self.parent = parent
        self.transform = transform
        super.init()

        for element in parent.value {
            _ = self._insert(newElement(element))
        }
        parent.updates.add(parentSink)
    }

    deinit {
        parent.updates.remove(parentSink)
        for (sink, field) in fields {
            field.updates.remove(sink)
        }
    }

    private func newElement(_ element: Parent.Element) -> Element {
        let field = transform(element)
        let sink = fieldSink(for: element)
        let old = fields.updateValue(field, forKey: sink)
        precondition(old == nil)
        return field.value
    }

    private func removeElement(_ element: Parent.Element) {
        let sink = fieldSink(for: element)
        let field = fields.removeValue(forKey: sink)!
        field.updates.remove(sink)
    }

    private func _insert(_ key: Element) -> Bool {
        if let count = contents[key] {
            contents[key] = count + 1
            return false
        }
        contents[key] = 1
        return true
    }

    private func insert(_ key: Element) -> ArrayModification<Element>? {
        return _insert(key) ? .insert(key, at: contents.offset(of: key)!) : nil
    }

    private func remove(_ key: Element) -> ArrayModification<Element>? {
        guard let count = self.contents[key] else {
            fatalError("Inconsistent change: element removed is not in sorted set")
        }
        if count > 1 {
            contents[key] = count - 1
            return nil
        }
        let oldOffset = contents.offset(of: key)!
        contents.removeValue(forKey: key)
        return .remove(key, at: oldOffset)
    }

    private var parentSink: AnySink<SetUpdate<Parent.Element>> {
        return StrongMethodSink(owner: self, identifier: 0, method: SetSortingByMappingToObservableComparable.applyParentUpdate).anySink
    }

    private func fieldSink(for element: Parent.Element) -> FieldSink {
        return StrongMethodSinkWithContext(owner: self,
                                     method: SetSortingByMappingToObservableComparable.applyFieldUpdate,
                                     context: element).anySink
    }

    private func applyParentUpdate(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            var arrayChange = ArrayChange<Element>(initialCount: contents.count)
            for element in change.removed {
                let key = transform(element).value
                removeElement(element)
                if let mod = self.remove(key) {
                    arrayChange.add(mod)
                }
            }
            for element in change.inserted {
                let key = newElement(element)
                if let mod = self.insert(key) {
                    arrayChange.add(mod)
                }
            }
            if !arrayChange.isEmpty {
                sendChange(arrayChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }

    private func applyFieldUpdate(_ update: ValueUpdate<Element>, for element: Parent.Element) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            var arrayChange = ArrayChange<Element>(initialCount: self.contents.count)
            if change.old == change.new { return }
            if let mod = remove(change.old) {
                arrayChange.add(mod)
            }
            if let mod = insert(change.new) {
                arrayChange.add(mod)
            }
            if !arrayChange.isEmpty {
                sendChange(arrayChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }

    override var isBuffered: Bool { return false }
    override subscript(index: Int) -> Element { return contents.element(atOffset: index).0 }
    override subscript(bounds: Range<Int>) -> ArraySlice<Element> { return ArraySlice(contents.submap(withOffsets: bounds).lazy.map { $0.0 }) }
    override var value: Array<Element> { return Array(contents.lazy.map { $0.0 }) }
    override var count: Int { return contents.count }
}
