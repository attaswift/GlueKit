//
//  UpdatableArray.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-11.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

//MARK: UpdatableArrayType

/// An observable array that you can modify.
///
/// Note that while `UpdatableArrayType` and `UpdatableArray` implement some methods from `MutableCollectionType` and
/// `RangeRaplacableCollectionType`, protocol conformance is intentionally not declared.
///
/// These collection protocols define their methods as mutable, which does not make sense for a generic updatable array,
/// which is often a proxy that forwards these methods somewhere else (via some transformations).
/// Also, it is not a good idea to do complex in-place manipulations (such as `sortInPlace`) on an array that has observers.
/// Instead of `updatableArray.sortInPlace()`, which is not available, consider using
/// `updatableArray.value = updatableArray.value.sort()`. The latter will probably be much more efficient.
public protocol UpdatableArrayType: ObservableArrayType {

    // Required members
    func apply(_ change: ArrayChange<Element>)
    var value: [Element] { get nonmutating set }
    subscript(index: Int) -> Element { get nonmutating set }
    subscript(bounds: Range<Int>) -> ArraySlice<Element> { get nonmutating set }

    // The following are defined in extensions but may be specialized in implementations:

    var updatable: Updatable<[Element]> { get }
    var updatableArray: UpdatableArray<Element> { get }

    func modify(_ block: (ArrayVariable<Element>) -> Void) -> Void
}

extension UpdatableArrayType {
    public var updatable: Updatable<[Element]> {
        return Updatable(
            getter: { self.value },
            setter: { self.value = $0 },
            futureValues: { self.futureChanges.map { _ in self.value } }
        )
    }

    public var updatableArray: UpdatableArray<Element> {
        return UpdatableArray(box: UpdatableArrayBox(self))
    }

    public func modify(_ block: (ArrayVariable<Element>) -> Void) -> Void {
        let array = ArrayVariable<Element>(self.value)
        var change = ArrayChange<Element>(initialCount: array.count)
        let connection = array.futureChanges.connect { c in change.merge(with: c) }
        block(array)
        connection.disconnect()
        self.apply(change)
    }

    public func replaceSubrange<C: Collection>(_ range: Range<Int>, with elements: C) where C.Iterator.Element == Element {
        let elements = elements as? Array<Element> ?? Array(elements)
        apply(ArrayChange(initialCount: self.count, modification: .replaceRange(range.lowerBound ..< range.upperBound, with: elements)))
    }

    public func append(_ newElement: Element) {
        let c = count
        apply(ArrayChange(initialCount: c, modification: .insert(newElement, at: c)))
    }

    public func append<C: Collection>(contentsOf newElements: C) where C.Iterator.Element == Element {
        let c = count
        let elements = newElements as? Array<Element> ?? Array(newElements)
        apply(ArrayChange(initialCount: c, modification: .replaceRange(c ..< c, with: elements)))
    }

    public func insert(_ newElement: Element, at i: Int) {
        let c = count
        apply(ArrayChange(initialCount: c, modification: .insert(newElement, at: i)))
    }

    public func insert<C: Collection>(contentsOf newElements: C, at i: Int) where C.Iterator.Element == Element {
        let c = count
        let elements = newElements as? Array<Element> ?? Array(newElements)
        apply(ArrayChange(initialCount: c, modification: .replaceRange(i ..< i, with: elements)))
    }

    @discardableResult
    public func remove(at index: Int) -> Element {
        let c = count
        let result = self[index]
        apply(ArrayChange(initialCount: c, modification: .removeElement(at: index)))
        return result
    }

    public func removeSubrange(_ subrange: Range<Int>) {
        let c = count
        apply(ArrayChange(initialCount: c, modification: .replaceRange(subrange.lowerBound ..< subrange.upperBound, with: [])))
    }

    @discardableResult
    public func removeFirst() -> Element {
        let c = count
        let result = self[0]
        apply(ArrayChange(initialCount: c, modification: .removeElement(at: 0)))
        return result
    }

    public func removeFirst(_ n: Int) {
        let c = count
        apply(ArrayChange(initialCount: c, modification: .replaceRange(0 ..< n, with: [])))
    }

    @discardableResult
    public func removeLast() -> Element {
        let c = count
        let result = self[c - 1]
        apply(ArrayChange(initialCount: c, modification: .removeElement(at: c - 1)))
        return result
    }

    public func removeAll() {
        let c = count
        apply(ArrayChange(initialCount: c, modification: .replaceRange(0 ..< c, with: [])))
    }
}


public struct UpdatableArray<Element>: UpdatableArrayType {
    public typealias Value = [Element]
    public typealias Base = [Element]
    public typealias Change = ArrayChange<Element>

    let box: UpdatableArrayBase<Element>

    init(box: UpdatableArrayBase<Element>) {
        self.box = box
    }

    public init<Contents: UpdatableArrayType>(_ contents: Contents) where Contents.Element == Element {
        self = contents.updatableArray
    }

    public var isBuffered: Bool { return box.isBuffered }
    public var count: Int { return box.count }
    public var futureChanges: Source<ArrayChange<Element>> { return box.futureChanges }

    public func apply(_ change: ArrayChange<Element>) { box.apply(change) }
    public var value: [Element] {
        get { return box.value }
        nonmutating set { box.value = newValue }
    }
    public subscript(index: Int) -> Element {
        get { return box[index] }
        nonmutating set { box[index] = newValue }
    }

    public subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        get { return box[bounds] }
        nonmutating set { box[bounds] = newValue }
    }

    public func modify(_ block: (ArrayVariable<Element>) -> Void) -> Void { box.modify(block) }

    public var observable: Observable<Array<Element>> { return box.observable }
    public var observableCount: Observable<Int> { return box.observableCount }
    public var updatable: Updatable<[Element]> { return box.updatable }
    public var updatableArray: UpdatableArray<Element> { return self }
}

internal class UpdatableArrayBase<Element>: ObservableArrayBase<Element>, UpdatableArrayType {

    func apply(_ change: ArrayChange<Element>) { abstract() }

    override var value: [Element] {
        get { abstract() }
        set { abstract() }
    }
    override subscript(index: Int) -> Element {
        get { abstract() }
        set { abstract() }
    }
    override subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        get { abstract() }
        set { abstract() }
    }

    func modify(_ block: (ArrayVariable<Element>) -> Void) -> Void { abstract() }

    // The following are defined in extensions but may be specialized in implementations:

    var updatable: Updatable<[Element]> { abstract() }

    final var updatableArray: UpdatableArray<Element> { return UpdatableArray(box: self) }
}

internal class UpdatableArrayBox<Contents: UpdatableArrayType>: UpdatableArrayBase<Contents.Element> {
    typealias Element = Contents.Element

    var contents: Contents

    init(_ contents: Contents) {
        self.contents = contents
    }

    override func apply(_ change: ArrayChange<Element>) {
        contents.apply(change)
    }

    override var value: [Element] {
        get { return contents.value }
        set { contents.value = newValue }
    }

    override subscript(index: Int) -> Element {
        get { return contents[index] }
        set { contents[index] = newValue }
    }

    override subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        get { return contents[bounds] }
        set { contents[bounds] = newValue }
    }

    override func modify(_ block: (ArrayVariable<Element>) -> Void) -> Void { contents.modify(block) }


    override var updatable: Updatable<Array<Contents.Element>> {
        return contents.updatable
    }

    override var isBuffered: Bool { return contents.isBuffered }
    override var count: Int { return contents.count }
    override var futureChanges: Source<ArrayChange<Element>> { return contents.futureChanges }
    override var observable: Observable<[Element]> { return contents.observable }
    override var observableCount: Observable<Int> { return contents.observableCount }
}
