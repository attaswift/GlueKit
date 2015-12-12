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
    func lookup(range: Range<Index>) -> SubSequence
    func apply(change: ArrayChange<Generator.Element>)
    var futureChanges: Source<ArrayChange<Generator.Element>> { get }

    // The following are defined in extensions but may be specialized in implementations:

    func setValue(value: [Generator.Element])
    var value: [Generator.Element] { get nonmutating set }
    subscript(index: Index) -> Generator.Element { get nonmutating set }
    subscript(bounds: Range<Index>) -> SubSequence { get nonmutating set }

    var updatableArray: UpdatableArray<Generator.Element> { get }

    func modify(@noescape block: ArrayVariable<Generator.Element>->Void) -> Void

    // RangeReplaceableCollectionType
    func replaceRange<C: CollectionType where C.Generator.Element == Generator.Element>(range: Range<Index>, with elements: C)
    func append(newElement: Self.Generator.Element)
    func appendContentsOf<C: CollectionType where C.Generator.Element == Generator.Element>(newElements: C)
    func insert(newElement: Self.Generator.Element, atIndex i: Self.Index)
    func insertContentsOf<C: CollectionType where C.Generator.Element == Generator.Element>(newElements: C, at i: Self.Index)
    func removeAtIndex(index: Self.Index) -> Self.Generator.Element
    func removeRange(subRange: Range<Self.Index>)
    func removeFirst(n: Int)
    func removeFirst() -> Self.Generator.Element
    func removeAll()
    func removeLast() -> Self.Generator.Element
}

extension UpdatableArrayType where
    Index == Int,
    Change == ArrayChange<Generator.Element>,
    SubSequence: CollectionType,
    SubSequence.Generator.Element == Generator.Element {

    public func setValue(value: [Generator.Element]) {
        replaceRange(Range(start: 0, end: count), with: value)
    }

    public var value: [Generator.Element] {
        get {
            let result = lookup(Range(start: 0, end: count))
            return result as? Array<Generator.Element> ?? Array(result)
        }
        nonmutating set {
            replaceRange(Range(start: 0, end: count), with: newValue)
        }
    }
    public subscript(index: Index) -> Generator.Element {
        get {
            let range = Range(start: index, end: index)
            return lookup(range).first!
        }
        nonmutating set {
            apply(ArrayChange(initialCount: self.count, modification: .Insert(newValue, at: index)))
        }
    }

    public subscript(bounds: Range<Index>) -> SubSequence {
        get {
            return lookup(bounds)
        }
        nonmutating set {
            replaceRange(bounds, with: Array(newValue))
        }
    }

    public var updatableArray: UpdatableArray<Generator.Element> {
        return UpdatableArray(self)
    }

    public func modify(@noescape block: ArrayVariable<Generator.Element>->Void) -> Void {
        let array = ArrayVariable<Generator.Element>(self.value)
        var change = ArrayChange<Generator.Element>(initialCount: array.count)
        let connection = array.futureChanges.connect { c in change.mergeInPlace(c) }
        block(array)
        connection.disconnect()
        self.apply(change)
    }


    public func replaceRange<C: CollectionType where C.Generator.Element == Generator.Element>(range: Range<Index>, with elements: C) {
        let elements = elements as? Array<Generator.Element> ?? Array(elements)
        apply(ArrayChange(initialCount: self.count, modification: .ReplaceRange(range, with: elements)))
    }

    public func append(newElement: Generator.Element) {
        let c = count
        replaceRange(Range(start: c, end: c), with: CollectionOfOne(newElement))
    }

    public func appendContentsOf<C : CollectionType where C.Generator.Element == Generator.Element>(newElements: C) {
        let c = count
        replaceRange(Range(start: c, end: c), with: newElements)
    }

    public func insert(newElement: Generator.Element, atIndex i: Index) {
        let change = ArrayChange(initialCount: self.count, modification: .Insert(newElement, at: i))
        apply(change)
    }

    public func insertContentsOf<C : CollectionType where C.Generator.Element == Generator.Element>(newElements: C, at i: Index) {
        replaceRange(Range(start: i, end: i), with: newElements)
    }

    public func removeAtIndex(index: Index) -> Generator.Element {
        let element = lookup(Range(start: index, end: index + 1)).first!
        apply(ArrayChange(initialCount: self.count, modification: .RemoveAt(index)))
        return element
    }

    public func removeRange(subRange: Range<Index>) {
        replaceRange(subRange, with: EmptyCollection())
    }

    public func removeFirst(n: Int) {
        replaceRange(Range(start: 0, end: n), with: EmptyCollection())
    }

    public func removeFirst() -> Generator.Element {
        let range = Range(start: 0, end: 1)
        let first = lookup(range)
        replaceRange(range, with: EmptyCollection())
        return first.first!
    }

    public func removeAll() {
        replaceRange(Range(start: 0, end: count), with: EmptyCollection())
    }

    public func removeLast() -> Generator.Element {
        let count = self.count
        let range = Range(start: count - 1, end: count)
        let last = lookup(range)
        replaceRange(range, with: EmptyCollection())
        return last.first!
    }
}


public struct UpdatableArray<Element>: UpdatableArrayType {
    public typealias Value = [Element]
    public typealias BaseCollection = [Element]
    public typealias Change = ArrayChange<Element>
    public typealias ObservableValue = [Element]

    public typealias Index = Int
    public typealias Generator = Array<Element>.Generator
    public typealias SubSequence = [Element]

    private let _observableArray: ObservableArray<Element>
    private let _apply: ArrayChange<Element>->Void

    public init(count: Void->Int, lookup: Range<Int>->Array<Element>, apply: ArrayChange<Element>->Void, futureChanges: Void->Source<ArrayChange<Element>>) {
        _observableArray = ObservableArray(count: count, lookup: lookup, futureChanges: futureChanges)
        _apply = apply
    }

    public init<A: UpdatableArrayType where A.Index == Int, A.Generator.Element == Element, A.Change == ArrayChange<Element>, A.SubSequence.Generator.Element == Element>(_ array: A) {
        _observableArray = ObservableArray(array)
        _apply = { change in array.apply(change) }
    }

    public var count: Int { return _observableArray.count }
    public func lookup(range: Range<Index>) -> [Element] { return _observableArray.lookup(range) }
    public func apply(change: ArrayChange<Generator.Element>) { _apply(change) }
    public var futureChanges: Source<ArrayChange<Element>> { return _observableArray.futureChanges }

    public var observableCount: Observable<Int> { return _observableArray.observableCount }
    public var observable: Observable<[Element]> { return _observableArray.observable }
    public var observableArray: ObservableArray<Element> { return _observableArray }
    public var updatableArray: UpdatableArray<Element> { return self }
}
