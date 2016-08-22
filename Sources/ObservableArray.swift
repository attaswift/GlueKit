//
//  ObservableArray.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-11.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public protocol ArrayLikeCollection: RandomAccessCollection {
    // These should be requirements, not defaults
    associatedtype Index = Int
    associatedtype IndexDistance = Int
    associatedtype Indices = CountableRange<Int>
}

extension ArrayLikeCollection where Index == Int, IndexDistance == Int, Indices == CountableRange<Int> {
    public var last: Iterator.Element? { return isEmpty ? nil : self[endIndex - 1] }

    public func distance(from start: Int, to end: Int) -> Int { return end - start }

    public func index(after i: Int) -> Int { return i + 1 }
    public func index(before i: Int) -> Int { return i - 1 }
    public func index(_ i: Int, offsetBy n: Int) -> Int { return i + n }
    public func index(_ i: Int, offsetBy n: Int, limitedBy limit: Int) -> Int? {
        let r = i + n
        if n < 0 {
            return r > limit ? r : nil
        }
        else {
            return r < limit ? r : nil
        }
    }

    public func formIndex(after i: inout Int) { i += 1 }
    public func formIndex(before i: inout Int) { i -= 1 }
    public func formIndex(_ i: inout Int, offsetBy n: Int) { i += n }
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
    associatedtype Base = Array<Iterator.Element>
    associatedtype Change = ArrayChange<Iterator.Element>

    // Required methods

    var count: Int { get }
    func lookup(_ range: Range<Int>) -> SubSequence
    var futureChanges: Source<ArrayChange<Iterator.Element>> { get }

    // From ObservableCollection
    var observableCount: Observable<Int> { get }
    var value: [Iterator.Element] { get }
    var observable: Observable<Base> { get }

    // Extras
    var observableArray: ObservableArray<Iterator.Element> { get }
}

extension ObservableArrayType where
    Index == Int,
    Base == Array<Iterator.Element>,
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
        return ObservableArray<Iterator.Element>(self)
    }
}

internal class ValueSourceForObservableArray<A: ObservableArrayType>: SignalDelegate where A.Change == ArrayChange<A.Iterator.Element> {
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

extension ObservableArrayType where Iterator.Element: Equatable {
    /// Elementwise comparison of two instances of an ObservableArrayType.
    /// This overload allows us to compare ObservableArrayTypes to array literals.
    public static func ==(a: Self, b: Self) -> Bool {
        return a.elementsEqual(b, by: ==)
    }
}

/// Elementwise comparison of any two ObservableArrayTypes.
public func ==<E: Equatable, A: ObservableArrayType, B: ObservableArrayType>(a: A, b: B) -> Bool where A.Iterator.Element == E, B.Iterator.Element == E {
        return a.elementsEqual(b, by: ==)
}

/// Elementwise comparison of any ObservableArrayType to an array.
public func ==<E: Equatable, A: ObservableArrayType>(a: A, b: [E]) -> Bool where A.Iterator.Element == E {
    return a.elementsEqual(b, by: ==)
}

/// Elementwise comparison of an array to any ObservableArrayType.
public func ==<E: Equatable, A: ObservableArrayType>(a: [E], b: A) -> Bool where A.Iterator.Element == E {
    return a.elementsEqual(b, by: ==)
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
    public typealias Base = [Element]
    public typealias Change = ArrayChange<Element>

    public typealias Iterator = Base.Iterator
    public typealias Index = Int
    public typealias IndexDistance = Int
    public typealias Indices = CountableRange<Int>
    public typealias SubSequence = Base.SubSequence

    private let _count: (Void) -> Int
    private let _lookup: (Range<Int>) -> Base.SubSequence
    private let _futureChanges: (Void) -> Source<ArrayChange<Element>>

    public init(count: @escaping (Void) -> Int, lookup: @escaping (Range<Int>) -> Base.SubSequence, futureChanges: @escaping (Void) -> Source<ArrayChange<Element>>) {
        _count = count
        _lookup = lookup
        _futureChanges = futureChanges
    }

    public init<A: ObservableArrayType>(_ array: A) where A.Index == Int, A.Iterator.Element == Element, A.Change == ArrayChange<Element>, A.SubSequence.Iterator.Element == Element {
        _count = { array.count }
        _lookup = { range in
            let result = array.lookup(range)
            return result as? SubSequence ?? SubSequence(result)
        }
        _futureChanges = { array.futureChanges }
    }

    public var count: Int { return _count() }
    public func lookup(_ range: Range<Int>) -> SubSequence { return _lookup(range) }
    public var futureChanges: Source<ArrayChange<Element>> { return _futureChanges() }

    public var observableArray: ObservableArray<Element> { return self }
}

extension ObservableArrayType {
    public static func constant(_ value: [Iterator.Element]) -> ObservableArray<Iterator.Element> {
        return ObservableArray(
            count: { 0 },
            lookup: { value[$0] },
            futureChanges: { Source.empty() })
    }

    public static func emptyConstant() -> ObservableArray<Iterator.Element> {
        return constant([])
    }
}
