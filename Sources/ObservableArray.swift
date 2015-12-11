//
//  ObservableArray.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-11.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

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
    typealias BaseCollection: CollectionType
    /// The type of this observable collection's change descriptions.
    typealias Change: ChangeType

    /// The count of elements in this observable; this is also (efficiently) observable.
    var observableCount: Observable<Int> { get }

    var value: BaseCollection { get }
    var futureChanges: Source<Change> { get }

    var observable: Observable<BaseCollection> { get }
}

//MARK: ChangeType

/// Describes a change to an observable that implements a collection of values.
/// An instance of a type implementing this protocol contains just enough information to reproduce the result of the
/// change from the previous value of the observable.
///
/// - SeeAlso: ArrayChange, ObservableArray, ArrayVariable
public protocol ChangeType {
    typealias Value

    /// Creates a new change description for a change that goes from `oldValue` to `newValue`.
    init(from oldValue: Value, to newValue: Value)

    /// Returns true if this change did not actually change the value of the observable.
    /// Noop changes aren't usually sent by observables, but it is possible to get them by merging a sequence of
    /// changes to a collection.
    var isNull: Bool { get }

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
    typealias BaseCollection = Array<Generator.Element>
    typealias Value = [Generator.Element]
    typealias Change = ArrayChange<Generator.Element>
    typealias Index = Int

    // This is included because although it is not actually required by CollectionType, we do want to use it in ObservableArray, below.
    subscript(bounds: Range<Int>) -> SubSequence { get }

    var observableArray: ObservableArray<Generator.Element> { get }
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

internal class ValueSourceForObservableArray<Element, A: ObservableArrayType where A.Generator.Element == Element, A.Change == ArrayChange<Element>>: SignalDelegate {
    internal typealias SourceValue = [Element]

    private let array: A

    private var _connection: Connection? = nil
    private var _values: [Element] = []
    private lazy var _signal: OwningSignal<[Element], ValueSourceForObservableArray<Element, A>> = { OwningSignal(delegate: self) }()

    internal init(array: A) {
        self.array = array
    }

    internal var source: Source<[Element]> { return _signal.source }

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

extension ObservableArrayType where BaseCollection == Array<Generator.Element>, Change == ArrayChange<Generator.Element> {
    public var observable: Observable<Array<Generator.Element>> {
        return Observable<Array<Generator.Element>>(getter: { self.value }, futureValues: {
            return ValueSourceForObservableArray(array: self).source
        })
    }
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
    public typealias Value = [Element]
    public typealias Change = ArrayChange<Element>
    public typealias ObservableValue = [Element]

    public typealias Index = Int
    public typealias Generator = AnyGenerator<Element>
    public typealias SubSequence = Array<Element>

    private let _count: Void->Int
    private let _lookup: Range<Int> -> Array<Element>
    private let _futureChanges: Void -> Source<ArrayChange<Element>>

    private var _futureCounts: Source<Int> {
        var connection: Connection? = nil
        let signal = Signal<Int>(
            start: { signal in
                connection = self.futureChanges.connect { change in
                    signal.send(change.finalCount)
                }
            },
            stop: { signal in
                connection?.disconnect()
                connection = nil
        })
        return signal.source
    }

    public init(count: Void->Int, lookup: Range<Int>->Array<Element>, futureChanges: Void->Source<ArrayChange<Element>>) {
        _count = count
        _lookup = lookup
        _futureChanges = futureChanges
    }

    public init<A: ObservableArrayType, S: SequenceType where A.Index == Int, S.Generator.Element == Element, A.Generator.Element == Element, A.Change == ArrayChange<Element>, A.SubSequence == S>(_ array: A) {
        _count = { array.count }
        _lookup = { range in Array(array[range]) }
        _futureChanges = { array.futureChanges }
    }

    public var value: [Element] { return Array(_lookup(Range(start: 0, end: count))) }
    public var futureChanges: Source<ArrayChange<Element>> { return _futureChanges() }

    public var count: Int { return _count() }
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return count }

    public subscript(index: Int) -> Element { return _lookup(Range(start: index, end: index + 1))[0] }
    public subscript(range: Range<Int>) -> Array<Element> { return _lookup(range) }

    public func generate() -> AnyGenerator<Element> {
        var index = 0
        return anyGenerator {
            if index < self.endIndex {
                let value = self[index]
                index += 1
                return value
            }
            else {
                return nil
            }
        }
    }

    public var observableArray: ObservableArray<Element> { return self }

    // TODO: Move this to an extension of ObservableArrayType once Swift's protocols grow up.
    public var observableCount: Observable<Int> {
        var count: Int? = nil
        return Observable(
            getter: {
                if let c = count {
                    assert(c == self.count)
                    return c
                }
                let c = self.count
                count = c
                return c
            },
            futureValues: {
                self.futureChanges.map { change in
                    let c = change.finalCount
                    count = c
                    return c
                }
        })
    }
}

