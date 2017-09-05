//
//  UpdatableArray.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-11.
//  Copyright © 2015–2017 Károly Lőrentey.
//

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
    var value: [Element] { get nonmutating set }
    func apply(_ update: ArrayUpdate<Element>)
    subscript(index: Int) -> Element { get nonmutating set }
    subscript(bounds: Range<Int>) -> ArraySlice<Element> { get nonmutating set }

    // The following are defined in extensions but may be specialized in implementations:

    var anyUpdatableValue: AnyUpdatableValue<[Element]> { get }
    var anyUpdatableArray: AnyUpdatableArray<Element> { get }
}

extension UpdatableArrayType {
    public func apply(_ update: Update<ValueChange<[Element]>>) {
        self.apply(update.map { change in ArrayChange(from: change.old, to: change.new) })
    }

    public var anyUpdatableValue: AnyUpdatableValue<[Element]> {
        return AnyUpdatableValue(getter: { self.value },
                                 apply: self.apply,
                                 updates: self.valueUpdates)
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
    public typealias Change = ArrayChange<Element>

    let box: _AbstractUpdatableArray<Element>

    init(box: _AbstractUpdatableArray<Element>) {
        self.box = box
    }

    public init<Updatable: UpdatableArrayType>(_ base: Updatable) where Updatable.Element == Element {
        self = base.anyUpdatableArray
    }

    public var isBuffered: Bool { return box.isBuffered }
    public var count: Int { return box.count }

    public func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<ArrayChange<Element>> {
        box.add(sink)
    }

    @discardableResult
    public func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<ArrayChange<Element>> {
        return box.remove(sink)
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

    public func apply(_ update: Update<ArrayChange<Element>>) {
        self.box.apply(update)
    }

    public var observableCount: AnyObservableValue<Int> { return box.observableCount }

    public var anyObservableValue: AnyObservableValue<Array<Element>> { return box.anyObservableValue }
    public var anyObservableArray: AnyObservableArray<Element> { return box.anyObservableArray }
    public var anyUpdatableValue: AnyUpdatableValue<[Element]> { return box.anyUpdatableValue }
    public var anyUpdatableArray: AnyUpdatableArray<Element> { return self }
}

open class _AbstractUpdatableArray<Element>: _AbstractObservableArray<Element>, UpdatableArrayType {

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

    open func apply(_ update: ArrayUpdate<Element>) { abstract() }

    open var anyUpdatableValue: AnyUpdatableValue<[Element]> {
        return AnyUpdatableValue(getter: { self.value },
                                 apply: self.apply,
                                 updates: self.valueUpdates)
    }

    public final var anyUpdatableArray: AnyUpdatableArray<Element> {
        return AnyUpdatableArray(box: self)
    }
}

open class _BaseUpdatableArray<Element>: _AbstractUpdatableArray<Element>, TransactionalThing {
    var _signal: TransactionalSignal<ArrayChange<Element>>? = nil
    var _transactionCount = 0

    func rawApply(_ change: ArrayChange<Element>) { abstract() }

    public final override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<ArrayChange<Element>> {
        signal.add(sink)
    }

    @discardableResult
    public final override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<ArrayChange<Element>> {
        return signal.remove(sink)
    }

    public final override func apply(_ update: Update<ArrayChange<Element>>) {
        switch update {
        case .beginTransaction:
            self.beginTransaction()
        case .change(let change):
            self.rawApply(change)
            self.sendChange(change)
        case .endTransaction:
            self.endTransaction()
        }
    }

    open func activate() {
        // Do nothing
    }

    open func deactivate() {
        // Do nothing
    }
}

internal final class UpdatableArrayBox<Contents: UpdatableArrayType>: _AbstractUpdatableArray<Contents.Element> {
    typealias Element = Contents.Element

    var contents: Contents

    init(_ contents: Contents) {
        self.contents = contents
    }

    override func apply(_ update: ArrayUpdate<Element>) {
        contents.apply(update)
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

    override var isBuffered: Bool { return contents.isBuffered }
    override var count: Int { return contents.count }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<ArrayChange<Element>> {
        contents.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<ArrayChange<Element>> {
        return contents.remove(sink)
    }

    override var observableCount: AnyObservableValue<Int> { return contents.observableCount }
    override var anyObservableValue: AnyObservableValue<[Element]> { return contents.anyObservableValue }
    override var anyUpdatableValue: AnyUpdatableValue<Array<Contents.Element>> { return contents.anyUpdatableValue }
}
