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
public protocol UpdatableArrayType: ObservableArrayType, UpdatableType {

    // Required members
    func apply(_ change: ArrayChange<Element>)
    var value: [Element] { get nonmutating set }
    subscript(index: Int) -> Element { get nonmutating set }
    subscript(bounds: Range<Int>) -> ArraySlice<Element> { get nonmutating set }

    // The following are defined in extensions but may be specialized in implementations:

    var anyUpdatable: AnyUpdatableValue<[Element]> { get }
    var anyUpdatableArray: AnyUpdatableArray<Element> { get }
}

extension UpdatableArrayType {
    public var anyUpdatable: AnyUpdatableValue<[Element]> {
        return AnyUpdatableValue(
            getter: { self.value },
            setter: { self.value = $0 },
            transaction: { self.withTransaction($0) },
            updates: { self.valueUpdates }
        )
    }

    public var anyUpdatableArray: AnyUpdatableArray<Element> {
        return AnyUpdatableArray(box: UpdatableArrayBox(self))
    }

    public func replaceSubrange<C: Collection>(_ range: Range<Int>, with elements: C) where C.Iterator.Element == Element {
        let old = Array(self[range])
        let new = elements as? Array<Element> ?? Array(elements)
        apply(ArrayChange(initialCount: self.count, modification: .replaceSlice(old, at: range.lowerBound, with: new)))
    }

    public func append(_ newElement: Element) {
        let c = count
        apply(ArrayChange(initialCount: c, modification: .insert(newElement, at: c)))
    }

    public func append<C: Collection>(contentsOf newElements: C) where C.Iterator.Element == Element {
        let c = count
        let new = newElements as? Array<Element> ?? Array(newElements)
        apply(ArrayChange(initialCount: c, modification: .replaceSlice([], at: c, with: new)))
    }

    public func insert(_ newElement: Element, at i: Int) {
        let c = count
        apply(ArrayChange(initialCount: c, modification: .insert(newElement, at: i)))
    }

    public func insert<C: Collection>(contentsOf newElements: C, at i: Int) where C.Iterator.Element == Element {
        let c = count
        let new = newElements as? Array<Element> ?? Array(newElements)
        apply(ArrayChange(initialCount: c, modification: .replaceSlice([], at: i, with: new)))
    }

    @discardableResult
    public func remove(at index: Int) -> Element {
        let c = count
        let old = self[index]
        apply(ArrayChange(initialCount: c, modification: .remove(old, at: index)))
        return old
    }

    public func removeSubrange(_ subrange: Range<Int>) {
        let c = count
        let old = Array(self[subrange])
        apply(ArrayChange(initialCount: c, modification: .replaceSlice(old, at: subrange.lowerBound, with: [])))
    }

    @discardableResult
    public func removeFirst() -> Element {
        let c = count
        let old = self[0]
        apply(ArrayChange(initialCount: c, modification: .remove(old, at: 0)))
        return old
    }

    public func removeFirst(_ n: Int) {
        let c = count
        let old = Array(self[0 ..< n])
        apply(ArrayChange(initialCount: c, modification: .replaceSlice(old, at: 0, with: [])))
    }

    @discardableResult
    public func removeLast() -> Element {
        let c = count
        let old = self[c - 1]
        apply(ArrayChange(initialCount: c, modification: .remove(old, at: c - 1)))
        return old
    }

    public func removeLast(_ n: Int) {
        let c = count
        let old = Array(self[count - n ..< count])
        apply(ArrayChange(initialCount: c, modification: .replaceSlice(old, at: count - n, with: [])))
    }

    public func removeAll() {
        let c = count
        let old = self.value
        apply(ArrayChange(initialCount: c, modification: .replaceSlice(old, at: 0, with: [])))
    }
}


public struct AnyUpdatableArray<Element>: UpdatableArrayType {
    public typealias Value = [Element]
    public typealias Base = [Element]
    public typealias Change = ArrayChange<Element>

    let box: _AbstractUpdatableArray<Element>

    init(box: _AbstractUpdatableArray<Element>) {
        self.box = box
    }

    public init<Updatable: UpdatableArrayType>(_ base: Updatable) where Updatable.Element == Element, Updatable.Change == ArrayChange<Element> {
        self = base.anyUpdatableArray
    }

    public var isBuffered: Bool { return box.isBuffered }
    public var count: Int { return box.count }
    public var updates: ArrayUpdateSource<Element> { return box.updates }

    public func withTransaction<Result>(_ body: () -> Result) -> Result {
        return self.box.withTransaction(body)
    }

    public func apply(_ change: ArrayChange<Element>) {
        box.apply(change)
    }

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

    public var observable: AnyObservableValue<Array<Element>> { return box.anyObservable }
    public var observableCount: AnyObservableValue<Int> { return box.observableCount }
    public var anyUpdatable: AnyUpdatableValue<[Element]> { return box.anyUpdatable }
    public var anyUpdatableArray: AnyUpdatableArray<Element> { return self }
}

open class _AbstractUpdatableArray<Element>: _AbstractObservableArray<Element>, UpdatableArrayType {

    open func apply(_ change: ArrayChange<Element>) { abstract() }

    open func withTransaction<Result>(_ body: () -> Result) -> Result { abstract() }

    open override var value: [Element] {
        get { abstract() }
        set { abstract() }
    }
    open override subscript(index: Int) -> Element {
        get { abstract() }
        set { abstract() }
    }
    open override subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        get { abstract() }
        set { abstract() }
    }

    open var anyUpdatable: AnyUpdatableValue<[Element]> {
        return AnyUpdatableValue(getter: { self.value },
                                 setter: { self.value = $0 },
                                 transaction: { self.withTransaction($0) },
                                 updates: { self.valueUpdates })
    }

    public final var anyUpdatableArray: AnyUpdatableArray<Element> {
        return AnyUpdatableArray(box: self)
    }
}

open class _BaseUpdatableArray<Element>: _AbstractUpdatableArray<Element>, LazyObserver {
    private var state = TransactionState<_BaseUpdatableArray, ArrayChange<Element>>()

    public final override var updates: ArrayUpdateSource<Element> {
        return state.source(retaining: self)
    }

    public final override func withTransaction<Result>(_ body: () -> Result) -> Result {
        state.begin()
        defer { state.end() }
        return body()
    }

    final var isConnected: Bool {
        return state.isConnected
    }

    final func beginTransaction() {
        state.begin()
    }

    final func endTransaction() {
        state.end()
    }

    final func sendChange(_ change: Change) {
        state.send(change)
    }

    open func startObserving() {
        // Do nothing
    }

    open func stopObserving() {
        // Do nothing
    }
}

internal class UpdatableArrayBox<Contents: UpdatableArrayType>: _AbstractUpdatableArray<Contents.Element> {
    typealias Element = Contents.Element

    var contents: Contents

    init(_ contents: Contents) {
        self.contents = contents
    }

    override func withTransaction<Result>(_ body: () -> Result) -> Result {
        return contents.withTransaction(body)
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

    override var anyUpdatable: AnyUpdatableValue<Array<Contents.Element>> {
        return contents.anyUpdatable
    }

    override var isBuffered: Bool { return contents.isBuffered }
    override var count: Int { return contents.count }
    override var updates: ArrayUpdateSource<Element> { return contents.updates }
    override var anyObservable: AnyObservableValue<[Element]> { return contents.anyObservable }
    override var observableCount: AnyObservableValue<Int> { return contents.observableCount }
}
