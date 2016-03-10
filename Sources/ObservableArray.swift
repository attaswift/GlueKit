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
    func applyOn(value: Value) -> Value

    /// Merge this change with the `next` change. The result is a single change description that describes the
    /// change of performing `self` followed by `next`.
    ///
    /// The resulting instance may take a shortcut when producing the result value if some information in `self`
    /// is overwritten by `next`.
    func merge(next: Self) -> Self
}

//MARK: ObservableCollectionType

/// An observable collection type; i.e., a read-only view into an observable collection of elements.
///
/// Observable collections have an observable element count, and provide a source that sends change descriptions whenever
/// the collection is modified. Each observable collection defines its own way to describe changes.
///
/// Note that observable collections do not implement `ObservableType`, but they do provide the `observable` getter to
/// explicitly convert them to one. This is because observing the value of the entire collection is expensive enough
/// to make sure you won't do it by accident.
public protocol ObservableCollectionType: CollectionType {
    /// The collection type underlying this observable collection.
    associatedtype BaseCollection: CollectionType
    /// The type of this observable collection's change descriptions.
    associatedtype Change: ChangeType

    associatedtype Generator = BaseCollection.Generator
    func generate() -> BaseCollection.Generator

    var count: Int { get }
    var observableCount: Observable<Int> { get }
    var value: BaseCollection { get }
    var futureChanges: Source<Change> { get }

    var observable: Observable<BaseCollection> { get }
}

extension ObservableCollectionType {
    public func generate() -> BaseCollection.Generator {
        return self.value.generate()
    }
}


//MARK: ObservableArrayType

/// An observable array type; i.e., a read-only, array-like `ObservableCollectionType` that provides efficient change
/// notifications.
///
/// Changes to an observable array are broadcast as a sequence of `ArrayChange` values, which describe insertions,
/// removals, and replacements.
///
/// Any `ObservableArrayType` can be converted into a type-lifted representation using `ObservableArray`.
/// For a concrete observable array, see `ArrayVariable`.
///
/// - SeeAlso: ObservableType, ObservableArray, UpdatableArrayType, ArrayVariable
public protocol ObservableArrayType: ObservableCollectionType { // Sadly there is no ArrayType in the standard library :-(
    associatedtype BaseCollection = Array<Generator.Element>
    associatedtype Change = ArrayChange<Generator.Element>
    associatedtype Index = Int

    // Required methods

    var count: Int { get }
    func lookup(range: Range<Int>) -> SubSequence
    var futureChanges: Source<ArrayChange<Generator.Element>> { get }

    // The following are defined in extensions but may be specialized in implementations:

    var startIndex: Int { get }
    var endIndex: Int { get }

    subscript(index: Int) -> Generator.Element { get }
    subscript(bounds: Range<Int>) -> SubSequence { get }

    // From ObservableCollectionType
    var observableCount: Observable<Int> { get }
    var value: [Generator.Element] { get }
    var observable: Observable<BaseCollection> { get }

    // Extras
    var observableArray: ObservableArray<Generator.Element> { get }
}

extension ObservableArrayType where
    Index == Int,
    BaseCollection == Array<Generator.Element>,
    Change == ArrayChange<Generator.Element>,
    SubSequence: CollectionType,
    SubSequence.Generator.Element == Generator.Element {

    public var startIndex: Int { return 0 }
    public var endIndex: Int { return count }

    public subscript(index: Int) -> Generator.Element {
        return lookup(index ..< index + 1).first!
    }
    public subscript(bounds: Range<Int>) -> SubSequence {
        return lookup(bounds)
    }

    public var observableCount: Observable<Int> {
        let fv: Void -> Source<Int> = { self.futureChanges.map { change in change.initialCount + change.deltaCount } }
        return Observable(
            getter: { self.count },
            futureValues: fv)
    }

    public var value: [Generator.Element] {
        let result = lookup(0 ..< count)
        return result as? Array<Generator.Element> ?? Array(result)
    }

    public var observable: Observable<Array<Generator.Element>> {
        return Observable<Array<Generator.Element>>(
            getter: { self.value },
            futureValues: { return ValueSourceForObservableArray(array: self).source })
    }

    public var observableArray: ObservableArray<Generator.Element> {
        return ObservableArray(self)
    }
}

internal class ValueSourceForObservableArray<A: ObservableArrayType where A.Change == ArrayChange<A.Generator.Element>>: SignalDelegate {
    internal typealias Element = A.Generator.Element

    private let array: A

    private var _signal = OwningSignal<[Element], ValueSourceForObservableArray<A>>()

    private var _connection: Connection? = nil
    private var _values: [Element] = []

    internal init(array: A) {
        self.array = array
    }

    internal var source: Source<[Element]> { return _signal.with(self).source }

    internal func start(signal: Signal<[Element]>) {
        assert(_values.count == 0 && _connection == nil)
        _values = Array(array)
        _connection = array.futureChanges.connect { change in
            self._values.apply(change)
            signal.send(self._values)
        }
    }
    internal func stop(signal: Signal<[Element]>) {
        _connection?.disconnect()
        _values.removeAll()
    }
}


/// Elementwise comparison of two instances of an ObservableArrayType.
/// This overload allows us to compare ObservableArrayTypes to array literals.
@warn_unused_result
public func ==<E: Equatable, A: ObservableArrayType where A.Generator.Element == E>(a: A, b: A) -> Bool {
    return a.elementsEqual(b, isEquivalent: ==)
}

/// Elementwise comparison of any two ObservableArrayTypes.
@warn_unused_result
public func ==<E: Equatable, A: ObservableArrayType, B: ObservableArrayType
    where A.Generator.Element == E, B.Generator.Element == E>
    (a: A, b: B) -> Bool {
        return a.elementsEqual(b, isEquivalent: ==)
}

/// Elementwise comparison of any ObservableArrayType to an array.
@warn_unused_result
public func ==<E: Equatable, A: ObservableArrayType where A.Generator.Element == E>(a: A, b: [E]) -> Bool {
    return a.elementsEqual(b, isEquivalent: ==)
}

/// Elementwise comparison of an array to any ObservableArrayType.
@warn_unused_result
public func ==<E: Equatable, A: ObservableArrayType where A.Generator.Element == E>(a: [E], b: A) -> Bool {
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
    public typealias Generator = Array<Element>.Generator
    public typealias SubSequence = Array<Element>

    private let _count: Void->Int
    private let _lookup: Range<Int> -> Array<Element>
    private let _futureChanges: Void -> Source<ArrayChange<Element>>

    public init(count: Void->Int, lookup: Range<Int>->Array<Element>, futureChanges: Void->Source<ArrayChange<Element>>) {
        _count = count
        _lookup = lookup
        _futureChanges = futureChanges
    }

    public init<A: ObservableArrayType where A.Index == Int, A.Generator.Element == Element, A.Change == ArrayChange<Element>, A.SubSequence.Generator.Element == Element>(_ array: A) {
        _count = { array.count }
        _lookup = { range in
            let result = array.lookup(range)
            return result as? Array<Element> ?? Array(result)
        }
        _futureChanges = { array.futureChanges }
    }

    public var count: Int { return _count() }
    public func lookup(range: Range<Int>) -> SubSequence { return _lookup(range) }
    public var futureChanges: Source<ArrayChange<Element>> { return _futureChanges() }

    public var observableArray: ObservableArray<Element> { return self }
}

