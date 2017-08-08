//
//  SetSortingByMappingToObservableComparable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2017-05-01.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import SipHash
import BTree

extension ObservableSetType where Element: AnyObject {
    /// Given a transformation into an observable of a comparable type, return an observable array
    /// containing transformed versions of elements in this set, in increasing order.
    public func sorted<Field: ObservableValueType>(by transform: @escaping (Element) -> Field) -> AnyObservableArray<Element> where Field.Value: Comparable {
        return SetSortingByComparableField(parent: self, transform: transform).anyObservableArray
    }
}

private class SetSortingByComparableField<Parent: ObservableSetType, Field: ObservableValueType>: _BaseObservableArray<Parent.Element>
where Parent.Element: AnyObject, Field.Value: Comparable {
    typealias Element = Parent.Element
    typealias Change = ArrayChange<Element>

    private struct ParentSink: UniqueOwnedSink {
        typealias Owner = SetSortingByComparableField

        unowned(unsafe) let owner: Owner

        func receive(_ update: SetUpdate<Parent.Element>) {
            owner.applyParentUpdate(update)
        }
    }

    private struct FieldSink: SinkType, SipHashable {
        typealias Owner = SetSortingByComparableField

        unowned(unsafe) let owner: Owner
        let element: Parent.Element

        func receive(_ update: ValueUpdate<Field.Value>) {
            owner.applyFieldUpdate(update, from: element)
        }

        func appendHashes(to hasher: inout SipHasher) {
            hasher.append(ObjectIdentifier(owner))
            hasher.append(element)
        }

        static func ==(left: FieldSink, right: FieldSink) -> Bool {
            return left.owner === right.owner && left.element == right.element
        }
    }
    

    private let parent: Parent
    private let transform: (Parent.Element) -> Field

    private var contents: BTree<Field.Value, Element> = .init()
    private var fields: Dictionary<FieldSink, Field> = [:]

    init(parent: Parent, transform: @escaping (Parent.Element) -> Field) {
        self.parent = parent
        self.transform = transform
        super.init()

        for element in parent.value {
            let key = newElement(element)
            _ = self.insert(key, element)
        }
        parent.add(ParentSink(owner: self))
    }

    deinit {
        parent.remove(ParentSink(owner: self))
        for (sink, field) in fields {
            field.remove(sink)
        }
    }

    private func newElement(_ element: Parent.Element) -> Field.Value {
        let field = transform(element)
        let sink = FieldSink(owner: self, element: element)
        let old = fields.updateValue(field, forKey: sink)
        field.add(sink)
        precondition(old == nil)
        return field.value
    }

    private func removeElement(_ element: Parent.Element) {
        let sink = FieldSink(owner: self, element: element)
        let field = fields.removeValue(forKey: sink)!
        field.remove(sink)
    }

    private func insert(_ key: Field.Value, _ element: Element) -> ArrayModification<Element> {
        return contents.withCursor(onKey: key, choosing: .after) { cursor in
            let offset = cursor.offset
            cursor.insert((key, element))
            return .insert(element, at: offset)
        }
    }

    private func remove(_ key: Field.Value, _ element: Element) -> ArrayModification<Element> {
        return contents.withCursor(onKey: key, choosing: .first) { cursor in
            while cursor.value !== element {
                cursor.moveForward()
                precondition(!cursor.isAtEnd, "Inconsistent change: element removed is not in sorted set")
            }
            let offset = cursor.offset
            return .remove(element, at: offset)
        }
    }

    func applyParentUpdate(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            var arrayChange = ArrayChange<Element>(initialCount: contents.count)
            for element in change.removed {
                let key = transform(element).value
                removeElement(element)
                arrayChange.add(self.remove(key, element))
            }
            for element in change.inserted {
                let key = newElement(element)
                arrayChange.add(self.insert(key, element))
            }
            if !arrayChange.isEmpty {
                sendChange(arrayChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }

    func applyFieldUpdate(_ update: ValueUpdate<Field.Value>, from element: Parent.Element) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            var arrayChange = ArrayChange<Element>(initialCount: self.contents.count)
            if change.old == change.new { return }
            arrayChange.add(remove(change.old, element))
            arrayChange.add(insert(change.new, element))
            if !arrayChange.isEmpty {
                sendChange(arrayChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }

    override var isBuffered: Bool { return false }
    override subscript(index: Int) -> Element { return contents.element(atOffset: index).1 }
    override subscript(bounds: Range<Int>) -> ArraySlice<Element> { return ArraySlice(contents.subtree(withOffsets: bounds).lazy.map { $0.1 }) }
    override var value: Array<Element> { return Array(contents.lazy.map { $0.1 }) }
    override var count: Int { return contents.count }
}
