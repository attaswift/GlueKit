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

    var count: Int { get }
    func lookup(_ range: Range<Index>) -> SubSequence
    func apply(_ change: ArrayChange<Iterator.Element>)
    var futureChanges: Source<ArrayChange<Iterator.Element>> { get }

    // The following are defined in extensions but may be specialized in implementations:

    func setValue(_ value: [Iterator.Element])
    var value: [Iterator.Element] { get nonmutating set }
    subscript(index: Index) -> Iterator.Element { get nonmutating set }
    subscript(bounds: Range<Index>) -> SubSequence { get nonmutating set }

    var updatableArray: UpdatableArray<Iterator.Element> { get }

    func modify(_ block: @noescape (ArrayVariable<Iterator.Element>) -> Void) -> Void

    // RangeReplaceableCollectionType
    func replaceSubrange<C: Collection where C.Iterator.Element == Iterator.Element>(_ range: Range<Index>, with elements: C)
    func append(_ newElement: Self.Iterator.Element)
    func append<C: Collection where C.Iterator.Element == Iterator.Element>(contentsOf newElements: C)
    func insert(_ newElement: Self.Iterator.Element, atIndex i: Self.Index)
    func insert<C: Collection where C.Iterator.Element == Iterator.Element>(contentsOf newElements: C, at i: Self.Index)

    @discardableResult
    func remove(at index: Self.Index) -> Self.Iterator.Element

    func removeSubrange(_ subrange: Range<Self.Index>)
    func removeFirst(_ n: Int)

    @discardableResult
    func removeFirst() -> Self.Iterator.Element
    func removeAll()

    @discardableResult
    func removeLast() -> Self.Iterator.Element
}

extension UpdatableArrayType where
    Index == Int,
    Change == ArrayChange<Iterator.Element>,
    Base == Array<Iterator.Element>,
    SubSequence: Collection,
    SubSequence.Iterator.Element == Iterator.Element {

    public func setValue(_ value: [Iterator.Element]) {
        replaceSubrange(0 ..< count, with: value)
    }

    public var value: [Iterator.Element] {
        get {
            let result = lookup(0 ..< count)
            return result as? Array<Iterator.Element> ?? Array(result)
        }
        nonmutating set {
            replaceSubrange(0 ..< count, with: newValue)
        }
    }
    public subscript(index: Index) -> Iterator.Element {
        get {
            return lookup(index ..< index).first!
        }
        nonmutating set {
            apply(ArrayChange(initialCount: self.count, modification: .insert(newValue, at: index)))
        }
    }

    public subscript(bounds: Range<Index>) -> SubSequence {
        get {
            return lookup(bounds)
        }
        nonmutating set {
            replaceSubrange(bounds, with: Array(newValue))
        }
    }

    public var updatable: Updatable<Base> {
        return Updatable(observable: observable, setter: { v in self.value = v })
    }

    public var updatableArray: UpdatableArray<Iterator.Element> {
        return UpdatableArray(self)
    }

    public func modify(_ block: @noescape (ArrayVariable<Iterator.Element>) -> Void) -> Void {
        let array = ArrayVariable<Iterator.Element>(self.value)
        var change = ArrayChange<Iterator.Element>(initialCount: array.count)
        let connection = array.futureChanges.connect { c in change.mergeInPlace(c) }
        block(array)
        connection.disconnect()
        self.apply(change)
    }


    public func replaceSubrange<C: Collection where C.Iterator.Element == Iterator.Element>(_ range: Range<Index>, with elements: C) {
        let elements = elements as? Array<Iterator.Element> ?? Array(elements)
        apply(ArrayChange(initialCount: self.count, modification: .replaceRange(range.lowerBound ..< range.upperBound, with: elements)))
    }

    public func append(_ newElement: Iterator.Element) {
        let c = count
        replaceSubrange(c ..< c, with: CollectionOfOne(newElement))
    }

    public func append<C : Collection where C.Iterator.Element == Iterator.Element>(contentsOf newElements: C) {
        let c = count
        replaceSubrange(c ..< c, with: newElements)
    }

    public func insert(_ newElement: Iterator.Element, atIndex i: Index) {
        let change = ArrayChange(initialCount: self.count, modification: .insert(newElement, at: i))
        apply(change)
    }

    public func insert<C : Collection where C.Iterator.Element == Iterator.Element>(contentsOf newElements: C, at i: Index) {
        replaceSubrange(i ..< i, with: newElements)
    }

    @discardableResult
    public func remove(at index: Index) -> Iterator.Element {
        let element = lookup(index ..< index + 1).first!
        apply(ArrayChange(initialCount: self.count, modification: .removeAt(index)))
        return element
    }

    public func removeSubrange(_ subRange: Range<Index>) {
        replaceSubrange(subRange, with: EmptyCollection())
    }

    public func removeFirst(_ n: Int) {
        replaceSubrange(0 ..< n, with: EmptyCollection())
    }

    @discardableResult
    public func removeFirst() -> Iterator.Element {
        let range: Range<Int> = 0 ..< 1
        let first = lookup(range)
        replaceSubrange(range, with: EmptyCollection())
        return first.first!
    }

    public func removeAll() {
        replaceSubrange(0 ..< count, with: EmptyCollection())
    }

    @discardableResult
    public func removeLast() -> Iterator.Element {
        let count = self.count
        let range: Range<Int> = count - 1 ..< count
        let last = lookup(range)
        replaceSubrange(range, with: EmptyCollection())
        return last.first!
    }
}


public struct UpdatableArray<Element>: UpdatableArrayType {
    public typealias Value = [Element]
    public typealias Base = [Element]
    public typealias Change = ArrayChange<Element>
    public typealias ObservableValue = [Element]

    public typealias Index = Int
    public typealias Indices = CountableRange<Int>
    public typealias IndexDistance = Int
    public typealias Iterator = Base.Iterator
    public typealias SubSequence = Base.SubSequence

    private let _observableArray: ObservableArray<Element>
    private let _apply: (ArrayChange<Element>) -> Void

    public init(count: (Void) -> Int, lookup: (Range<Int>) -> ArraySlice<Element>, apply: (ArrayChange<Element>) -> Void, futureChanges: (Void) -> Source<ArrayChange<Element>>) {
        _observableArray = ObservableArray(count: count, lookup: lookup, futureChanges: futureChanges)
        _apply = apply
    }

    public init<A: UpdatableArrayType where A.Index == Int, A.Iterator.Element == Element, A.Change == ArrayChange<Element>, A.SubSequence.Iterator.Element == Element>(_ array: A) {
        _observableArray = ObservableArray(array)
        _apply = { change in array.apply(change) }
    }

    public var count: Int { return _observableArray.count }
    public func lookup(_ range: Range<Index>) -> ArraySlice<Element> { return _observableArray.lookup(range) }
    public func apply(_ change: ArrayChange<Iterator.Element>) { _apply(change) }
    public var futureChanges: Source<ArrayChange<Element>> { return _observableArray.futureChanges }

    public var observableCount: Observable<Int> { return _observableArray.observableCount }
    public var observable: Observable<[Element]> { return _observableArray.observable }

    public var observableArray: ObservableArray<Element> { return _observableArray }
    public var updatableArray: UpdatableArray<Element> { return self }
}
