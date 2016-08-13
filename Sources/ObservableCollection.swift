//
//  ObservableCollection.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-12.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

//MARK: ChangeType

/// Describes a change to an observable that implements a collection of values.
/// An instance of a type implementing this protocol contains just enough information to reproduce the result of the
/// change from the previous value of the observable.
///
/// - SeeAlso: ArrayChange, ObservableArray, ArrayVariable
public protocol ChangeType {
    associatedtype Value

    /// Creates a new change description for a change that goes from `oldValue` to `newValue`.
    init(from oldValue: Value, to newValue: Value)

    /// Returns true if this change did not actually change the value of the observable.
    /// Noop changes aren't usually sent by observables, but it is possible to get them by merging a sequence of
    /// changes to a collection.
    var isEmpty: Bool { get }

    /// Applies this change on `value`, returning the new value.
    /// Note that `value` must be the same value as the one this change was created from.
    func apply(on value: Value) -> Value

    /// Merge this change with the `next` change. The result is a single change description that describes the
    /// change of performing `self` followed by `next`.
    ///
    /// The resulting instance may take a shortcut when producing the result value if some information in `self`
    /// is overwritten by `next`.
    func merged(with next: Self) -> Self
}

//MARK: ObservableCollection

/// An observable collection type; i.e., a read-only view into an observable collection of elements.
///
/// Observable collections have an observable element count, and provide a source that sends change descriptions whenever
/// the collection is modified. Each observable collection defines its own way to describe changes.
///
/// Note that observable collections do not implement `ObservableType`, but they do provide the `observable` getter to
/// explicitly convert them to one. This is because observing the value of the entire collection is expensive enough
/// to make sure you won't do it by accident.
public protocol ObservableCollection: Collection {
    /// The collection type underlying this observable collection.
    associatedtype Base: Collection
    /// The type of this observable collection's change descriptions.
    associatedtype Change: ChangeType

    associatedtype Index = Base.Index
    associatedtype Iterator = Base.Iterator
    associatedtype IndexDistance = Base.IndexDistance
    associatedtype SubSequence = Base.SubSequence

    var value: Base { get }

    var observableCount: Observable<Base.IndexDistance> { get }
    var futureChanges: Source<Change> { get }

    var observable: Observable<Base> { get }
}

extension ObservableCollection where Iterator == Base.Iterator, Index == Base.Index, Indices == Base.Indices, IndexDistance == Base.IndexDistance, SubSequence == Base.SubSequence {

    public func makeIterator() -> Base.Iterator { return self.value.makeIterator() }

    public var startIndex: Index { return self.value.startIndex }
    public var endIndex: Index { return self.value.endIndex }

    public var indices: Indices { return self.value.indices }

    public subscript(position: Index) -> Iterator.Element { return self.value[position] }
    public subscript(bounds: Range<Index>) -> SubSequence { return self.value[bounds] }

    public func prefix(upTo end: Index) -> SubSequence { return self.value.prefix(upTo: end) }
    public func suffix(from start: Index) -> SubSequence { return self.value.suffix(from: start) }
    public func prefix(through end: Index) -> SubSequence { return self.value.prefix(through: end) }

    public var isEmpty: Bool { return self.value.isEmpty }
    public var count: IndexDistance { return self.value.count }

    public var first: Iterator.Element? { return self.value.first }

    public func index(after i: Index) -> Index { return self.value.index(after: i) }
    public func index(_ i: Index, offsetBy n: IndexDistance) -> Index { return self.value.index(i, offsetBy: n) }
    public func index(_ i: Index, offsetBy n: IndexDistance, limitedBy limit: Index) -> Index? { return self.index(i, offsetBy: n, limitedBy: limit) }
    public func formIndex(_ i: inout Index, offsetBy n: IndexDistance) { self.value.formIndex(&i, offsetBy: n) }
    public func formIndex(_ i: inout Index, offsetBy n: IndexDistance, limitedBy limit: Index) -> Bool { return self.value.formIndex(&i, offsetBy: n, limitedBy: limit) }
    public func formIndex(after i: inout Index) { self.value.formIndex(after: &i) }

    public func distance(from start: Index, to end: Index) -> IndexDistance { return self.value.distance(from: start, to: end) }

}

