//
//  ObservableArray.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-11.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
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
    func applyOn(_ value: Value) -> Value

    /// Merge this change with the `next` change. The result is a single change description that describes the
    /// change of performing `self` followed by `next`.
    ///
    /// The resulting instance may take a shortcut when producing the result value if some information in `self`
    /// is overwritten by `next`.
    func merge(_ next: Self) -> Self
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
    associatedtype BaseCollection: Collection
    /// The type of this observable collection's change descriptions.
    associatedtype Change: ChangeType

    associatedtype Iterator = BaseCollection.Iterator
    func makeIterator() -> BaseCollection.Iterator

    var count: Int { get }
    var observableCount: Observable<Int> { get }
    var value: BaseCollection { get }
    var futureChanges: Source<Change> { get }

    var observable: Observable<BaseCollection> { get }
}

extension ObservableCollection {
    public func makeIterator() -> BaseCollection.Iterator {
        return self.value.makeIterator()
    }
}

public protocol ArrayLikeCollection: RandomAccessCollection {
    associatedtype Index = Int
    associatedtype IndexDistance = Int
    associatedtype Indices = CountableRange<Int>
    
    func distance(from start: Int, to end: Int) -> Int
    func index(after i: Int) -> Int
    func index(before i: Int) -> Int
    func index(_ i: Int, offsetBy n: Int) -> Int
    func index(_ i: Int, offsetBy n: Int, limitedBy limit: Int) -> Int?
    func formIndex(after i: inout Int)
    func formIndex(before i: inout Int)
    func formIndex(_ i: inout Int, offsetBy n: Int)
    func formIndex(_ i: inout Int, offsetBy n: Int, limitedBy limit: Int) -> Bool
}

extension ArrayLikeCollection where Index == Int, IndexDistance == Int, Indices == CountableRange<Int> {
    public func distance(from start: Int, to end: Int) -> Int {
        return end - start
    }

    public func index(after i: Int) -> Int {
        return i + 1
    }

    public func index(before i: Int) -> Int {
        return i - 1
    }

    public func index(_ i: Int, offsetBy n: Int) -> Int {
        return i + n
    }

    public func index(_ i: Int, offsetBy n: Int, limitedBy limit: Int) -> Int? {
        let r = i + n
        if n < 0 {
            return r > limit ? r : nil
        }
        else {
            return r < limit ? r : nil
        }
    }

    public func formIndex(after i: inout Int) {
        i += 1
    }

    public func formIndex(before i: inout Int) {
        i -= 1
    }

    public func formIndex(_ i: inout Int, offsetBy n: Int) {
        i += n
    }

    public func formIndex(_ i: inout Int, offsetBy n: Int, limitedBy limit: Int) -> Bool {
        if (n >= 0 && i + n > limit) || (n < 0 && i + n < limit) {
            i = limit
            return false
        }
        i += n
        return true
    }
}


//MARK: ObservableArrayType

/// An observable array type; i.e., a read-only, array-like `ObservableCollection` that provides efficient change
/// notifications.
///
/// Changes to an observable array are broadcast as a sequence of `ArrayChange` values, which describe insertions,
/// removals, and replacements.
///
/// Any `ObservableArrayType` can be converted into a type-lifted representation using `ObservableArray`.
/// For a concrete observable array, see `ArrayVariable`.
///
/// - SeeAlso: ObservableType, ObservableArray, UpdatableArrayType, ArrayVariable
public protocol ObservableArrayType: ObservableCollection, ArrayLikeCollection {
    associatedtype BaseCollection = Array<Iterator>
    associatedtype Change = ArrayChange<Iterator.Element>

    // Required methods

    var count: Int { get }
    func lookup(_ range: Range<Int>) -> SubSequence
    var futureChanges: Source<ArrayChange<Iterator.Element>> { get }

    // From ObservableCollection
    var observableCount: Observable<Int> { get }
    var value: [Iterator.Element] { get }
    var observable: Observable<BaseCollection> { get }

    // Extras
    var observableArray: ObservableArray<Iterator.Element> { get }
}

extension ObservableArrayType where
    Index == Int,
    BaseCollection == Array<Iterator.Element>,
    Change == ArrayChange<Iterator.Element>,
    SubSequence: Collection,
    SubSequence.Iterator.Element == Iterator.Element {

    public var startIndex: Int { return 0 }
    public var endIndex: Int { return count }

    public subscript(index: Int) -> Iterator.Element {
        return lookup(index ..< index + 1).first!
    }
    public subscript(bounds: Range<Int>) -> SubSequence {
        return lookup(bounds)
    }

    public var observableCount: Observable<Int> {
        let fv: (Void) -> Source<Int> = { self.futureChanges.map { change in change.initialCount + change.deltaCount } }
        return Observable(
            getter: { self.count },
            futureValues: fv)
    }

    public var value: [Iterator.Element] {
        let result = lookup(0 ..< count)
        return result as? Array<Iterator.Element> ?? Array(result)
    }

    public var observable: Observable<Array<Iterator.Element>> {
        return Observable<Array<Iterator.Element>>(
            getter: { self.value },
            futureValues: { return ValueSourceForObservableArray(array: self).source })
    }

    public var observableArray: ObservableArray<Iterator.Element> {
        return ObservableArray(self)
    }
}

internal class ValueSourceForObservableArray<A: ObservableArrayType where A.Change == ArrayChange<A.Iterator.Element>>: SignalDelegate {
    internal typealias Element = A.Iterator.Element

    private let array: A

    private var _signal = OwningSignal<[Element], ValueSourceForObservableArray<A>>()

    private var _connection: Connection? = nil
    private var _values: [Element] = []

    internal init(array: A) {
        self.array = array
    }

    internal var source: Source<[Element]> { return _signal.with(self).source }

    internal func start(_ signal: Signal<[Element]>) {
        assert(_values.count == 0 && _connection == nil)
        _values = Array(array)
        _connection = array.futureChanges.connect { change in
            self._values.apply(change)
            signal.send(self._values)
        }
    }
    internal func stop(_ signal: Signal<[Element]>) {
        _connection?.disconnect()
        _values.removeAll()
    }
}


/// Elementwise comparison of two instances of an ObservableArrayType.
/// This overload allows us to compare ObservableArrayTypes to array literals.
public func ==<E: Equatable, A: ObservableArrayType where A.Iterator.Element == E>(a: A, b: A) -> Bool {
    return a.elementsEqual(b, isEquivalent: ==)
}

/// Elementwise comparison of any two ObservableArrayTypes.
public func ==<E: Equatable, A: ObservableArrayType, B: ObservableArrayType
    where A.Iterator.Element == E, B.Iterator.Element == E>
    (a: A, b: B) -> Bool {
        return a.elementsEqual(b, isEquivalent: ==)
}

/// Elementwise comparison of any ObservableArrayType to an array.
public func ==<E: Equatable, A: ObservableArrayType where A.Iterator.Element == E>(a: A, b: [E]) -> Bool {
    return a.elementsEqual(b, isEquivalent: ==)
}

/// Elementwise comparison of an array to any ObservableArrayType.
public func ==<E: Equatable, A: ObservableArrayType where A.Iterator.Element == E>(a: [E], b: A) -> Bool {
    return a.elementsEqual(b, isEquivalent: ==)
}

/// An observable array type; i.e., a read-only, array-like `CollectionType` that also provides efficient change
/// notifications.
///
/// Changes to an observable array are broadcast as a sequence of `ArrayChange` values, which describe insertions,
/// removals, and replacements.
/// The count of elements in an `ObservableArrayType` is itself observable via its `observableCount` property.
///
/// Any `ObservableArrayType` can be converted into a type-lifted representation using `ObservableArray`.
/// For a concrete observable array, see `ArrayVariable`.
///
/// - SeeAlso: ObservableType, ObservableArrayType, UpdatableArrayType, ArrayVariable
public struct ObservableArray<Element>: ObservableArrayType {
    public typealias BaseCollection = [Element]
    public typealias Change = ArrayChange<Element>

    public typealias Index = Int
    public typealias IndexDistance = Int
    public typealias Indices = CountableRange<Int>
    public typealias Iterator = Array<Element>.Iterator
    public typealias SubSequence = Array<Element>

    private let _count: (Void) -> Int
    private let _lookup: (Range<Int>) -> Array<Element>
    private let _futureChanges: (Void) -> Source<ArrayChange<Element>>

    public init(count: (Void) -> Int, lookup: (Range<Int>) -> Array<Element>, futureChanges: (Void) -> Source<ArrayChange<Element>>) {
        _count = count
        _lookup = lookup
        _futureChanges = futureChanges
    }

    public init<A: ObservableArrayType where A.Index == Int, A.Iterator.Element == Element, A.Change == ArrayChange<Element>, A.SubSequence.Iterator.Element == Element>(_ array: A) {
        _count = { array.count }
        _lookup = { range in
            let result = array.lookup(range)
            return result as? Array<Element> ?? Array(result)
        }
        _futureChanges = { array.futureChanges }
    }

    public var count: Int { return _count() }
    public func lookup(_ range: Range<Int>) -> SubSequence { return _lookup(range) }
    public var futureChanges: Source<ArrayChange<Element>> { return _futureChanges() }

    public var observableArray: ObservableArray<Element> { return self }
}

