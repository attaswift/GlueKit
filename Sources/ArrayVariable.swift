//
//  ArrayVariable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-08.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

//MARK: ArrayModification

/// Describes a single modification of an array. The modification can be an insertion, a removal, a replacement or
/// a generic range replacement. All indices are understood to be based in the original array, before this modification
/// has taken place.
///
/// Every modification can be converted to a range replacement by using the `range` and `elements` properties.
/// There is an initializer to convert a pair of `range` and `elements` back into a modification.
public enum ArrayModification<Element> {
    /// The insertion of a single element at the specified position.
    case Insert(Element, at: Int)
    /// The removal of a single element at the specified position.
    case RemoveAt(Int)
    /// The replacement of a single element at the specified position with the specified new element.
    case ReplaceAt(Int, with: Element)
    /// The replacement of the specified contiguous range of elements with the specified new list of elements.
    /// The count of the range need not equal the replacement element count.
    ///
    /// Note that all other modification cases have an equivalent range replacement.
    /// We chose to keep them separate only because they are more expressive that way.
    case ReplaceRange(Range<Int>, with: [Element])

    /// Convert a contiguous replacement range and a replacement list of elements into a modification.
    public init(range: Range<Int>, elements: [Element]) {
        switch (range.count, elements.count) {
        case (0, 0):
            self = .ReplaceRange(range, with: elements) // Well. What can you do
        case (0, 1):
            self = .Insert(elements[0], at: range.startIndex)
        case (1, 0):
            self = .RemoveAt(range.startIndex)
        case (1, 1):
            self = .ReplaceAt(range.startIndex, with: elements[0])
        default:
            self = .ReplaceRange(range, with: elements)
        }

    }

    /// The effect of this modification on the element count of the array.
    var deltaCount: Int {
        switch self {
        case .Insert(_, at: _): return 1
        case .RemoveAt(_): return -1
        case .ReplaceAt(_, with: _): return 0
        case .ReplaceRange(let range, with: let es): return es.count - range.count
        }
    }

    /// The range (in the original array) that this modification replaces, when converted into a range modification.
    public var range: Range<Int> {
        switch self {
        case .Insert(_, at: let i):
            return Range(start: i, end: i)
        case .RemoveAt(let i):
            return Range(start: i, end: i + 1)
        case .ReplaceAt(let i, with: _):
            return Range(start: i, end: i + 1)
        case .ReplaceRange(let range, with: _):
            return range
        }
    }

    /// The replacement elements that this modification inserts into the array in place of the old elements in `range`.
    public var elements: [Element] {
        switch self {
        case .Insert(let e, at: _):
            return [e]
        case .RemoveAt(_):
            return []
        case .ReplaceAt(_, with: let e):
            return [e]
        case .ReplaceRange(_, with: let es):
            return es
        }
    }

    /// Try to merge `mod` into this modification and return the result.
    func merge(mod: ArrayModification<Element>) -> ArrayModificationMergeResult<Element> {
        let range1 = self.range
        let range2 = mod.range

        let elements1 = self.elements
        let elements2 = mod.elements

        if range1.startIndex + elements1.count < range2.startIndex {
            // New range affects indices greater than our range
            return .DisjunctOrderedAfter
        }
        else if range2.endIndex < range1.startIndex {
            // New range affects indices earlier than our range
            return .DisjunctOrderedBefore
        }

        // There is some overlap.
        let delta = elements1.count - range1.count

        let combinedRange = Range<Int>(
            start: min(range1.startIndex, range2.startIndex),
            end: max(range1.endIndex, range2.endIndex - delta)
        )

        let replacement = Range<Int>(
            start: max(0, range2.startIndex - range1.startIndex),
            end: min(elements1.count, range2.endIndex - range1.startIndex))
        var combinedElements = elements1
        combinedElements.replaceRange(replacement, with: elements2)

        if combinedRange.count == 0 && combinedElements.count == 0 {
            return .CollapsedToNoChange
        }
        else {
            return .CollapsedTo(ArrayModification(range: combinedRange, elements: combinedElements))
        }
    }

    /// Transform each element in this modification using the function `transform`.
    public func map<Result>(transform: Element->Result) -> ArrayModification<Result> {
        switch self {
        case .Insert(let e, at: let i):
            return .Insert(transform(e), at: i)
        case .RemoveAt(let i):
            return .RemoveAt(i)
        case .ReplaceAt(let i, with: let e):
            return .ReplaceAt(i, with: transform(e))
        case .ReplaceRange(let range, with: let es):
            return .ReplaceRange(range, with: es.map(transform))
        }
    }

    /// Add the specified delta to all indices in this modification.
    public func shift(delta: Int) -> ArrayModification<Element> {
        switch self {
        case .Insert(let e, at: let i):
            return .Insert(e, at: i + delta)
        case .RemoveAt(let i):
            return .RemoveAt(i + delta)
        case .ReplaceAt(let i, with: let e):
            return .ReplaceAt(i + delta, with: e)
        case .ReplaceRange(let range, with: let es):
            return .ReplaceRange(range.startIndex + delta ..< range.endIndex + delta, with: es)
        }
    }
}

/// The result of an attempt at merging two array modifications.
internal enum ArrayModificationMergeResult<Element> {
    /// The modifications are disjunct, and the new modification changes indexes below the old.
    case DisjunctOrderedBefore
    /// The modifications are disjunct, and the new modification changes indexes above the old.
    case DisjunctOrderedAfter
    /// The modifications are intersecting, and cancel each other out.
    case CollapsedToNoChange
    /// The modifications are intersecting, and merge to the specified new modification.
    case CollapsedTo(ArrayModification<Element>)
}

extension RangeReplaceableCollectionType where Index == Int {
    /// Apply `modification` to this array in place.
    internal mutating func apply(modification: ArrayModification<Generator.Element>) {
        switch modification {
        case .Insert(let element, at: let index):
            self.insert(element, atIndex: index)
        case .RemoveAt(let index):
            self.removeAtIndex(index)
        case .ReplaceAt(let index, with: let element):
            self.replaceRange(Range(start: index, end: index + 1), with: [element])
        case .ReplaceRange(let range, with: let elements):
            self.replaceRange(range, with: elements)
        }
    }
}

public func ==<Element: Equatable>(a: ArrayModification<Element>, b: ArrayModification<Element>) -> Bool {
    return a.range == b.range && a.elements == b.elements
}

//MARK: ArrayChange

/// ArrayChange describes a series of one or more modifications to an array. Each modification is the replacement of
/// a contiguous range of elements with another set of elements (see `ArrayModification`).
///
/// You can efficiently merge array changes together forming a single change, without constructing the whole array 
/// in between. You can also transform values contained array changes using any transform function.
///
/// Array changes may only be applied on arrays that have the same number of elements as the original array.
/// 
/// - SeeAlso: ArrayModification, ObservableArray, ArrayVariable
public struct ArrayChange<Element>: ChangeType {
    public typealias Value = [Element]

    /// The expected initial count of elements in the array on the input of this change.
    public private(set) var initialCount: Int

    /// The expected final count of elements in the array on the output of this change.
    public private(set) var finalCount: Int

    /// The sequence of independent modifications to apply, in order of the start indexes of their ranges.
    /// All indices are understood to be in the array resulting from the original array by applying all
    /// earlier modifications. (So you can simply loop over the modifications and apply them one by one.)
    public private(set) var modifications: [ArrayModification<Element>] = []

    internal init(initialCount: Int, finalCount: Int, modifications: [ArrayModification<Element>]) {
        assert(finalCount == initialCount + modifications.reduce(0, combine: { c, m in c + m.deltaCount }))
        self.initialCount = initialCount
        self.finalCount = finalCount
        self.modifications = modifications
    }

    /// Initializes a change with `count` as the expected initial count and consisting of `modification`.
    public init(count: Int, modification: ArrayModification<Element>) {
        self.init(initialCount: count, finalCount: count + modification.deltaCount, modifications: [modification])
    }

    /// Initializes a change that simply replaces all elements in `previousValue` with the ones in `newValue`.
    public init(from previousValue: Value, to newValue: Value) {
        // Elements aren't necessarily equatable here, so this is the best we can do.
        self.init(count: previousValue.count, modification: .ReplaceRange(0..<previousValue.count, with: newValue))
    }

    /// Returns true if this change contains no actual changes to the array.
    /// This can happen if a series of merged changes cancel each other out---such as the insertion of an element 
    /// and the subsequent removal of the same.
    public var isNull: Bool { return modifications.isEmpty }

    private mutating func addModification(new: ArrayModification<Element>) {
        finalCount += new.deltaCount
        var pos = modifications.count - 1
        var m = new
        while pos >= 0 {
            let old = modifications[pos]
            let res = old.merge(m)
            switch res {
            case .DisjunctOrderedAfter:
                modifications.insert(m, atIndex: pos + 1)
                return
            case .DisjunctOrderedBefore:
                modifications[pos] = old.shift(m.deltaCount)
                pos -= 1
                continue
            case .CollapsedToNoChange:
                modifications.removeAtIndex(pos)
                return
            case .CollapsedTo(let merged):
                modifications.removeAtIndex(pos)
                m = merged
                pos -= 1
                continue
            }
        }
        modifications.insert(m, atIndex: 0)
    }

    /// Apply this change on `value`, which must have a count equal to the `initialCount` of this change.
    public func applyOn(value: [Element]) -> [Element] {
        precondition(value.count == initialCount)
        var result = value
        result.apply(self)
        return result
    }

    /// Merge `other` into this change, modifying it in place.
    /// `other.initialCount` must be equal to `self.finalCount`, or the merge will report a fatal error.
    public mutating func mergeInPlace(other: ArrayChange<Element>) {
        precondition(finalCount == other.initialCount)
        for m in other.modifications {
            addModification(m)
        }
        assert(finalCount == other.finalCount)
    }

    /// Returns a new change that contains all changes in this change plus all changes in `other`.
    /// `other.initialCount` must be equal to `self.finalCount`, or the merge will report a fatal error.
    @warn_unused_result
    public func merge(other: ArrayChange<Element>) -> ArrayChange<Element> {
        var result = self
        result.mergeInPlace(other)
        return result
    }

    /// Transform all element values contained in this change using the `transform` function.
    public func map<Result>(transform: Element->Result) -> ArrayChange<Result> {
        return ArrayChange<Result>(initialCount: initialCount, finalCount: finalCount,
            modifications: modifications.map { $0.map(transform) })
    }
}

public func ==<Element: Equatable>(a: ArrayChange<Element>, b: ArrayChange<Element>) -> Bool {
    return (a.initialCount == b.initialCount
        && a.finalCount == b.finalCount
        && a.modifications.elementsEqual(b.modifications, isEquivalent: ==))
}

extension RangeReplaceableCollectionType where Index == Int {
    /// Apply `change` to this array. The count of self must be the same as the initial count of `change`, or
    /// the operation will report a fatal error.
    public mutating func apply(change: ArrayChange<Generator.Element>) {
        precondition(self.count == change.initialCount)
        for modification in change.modifications {
            self.apply(modification)
        }
        assert(self.count == change.finalCount)
    }
}

//MARK: ArrayVariable

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
/// - SeeAlso: ObservableType, ObservableArray, UpdatableArrayType, ArrayVariable
public protocol ObservableArrayType: ObservableType, CollectionType {
    // TODO: Do these hurt more than they help? Swift 2.1.1 allows implementations to override these restrictions :-(
    typealias ObservableValue = [Generator.Element]
    typealias Change = ArrayChange<Generator.Element>
    typealias Index = Int
    typealias SubSequence = ArraySlice<Generator.Element>

    /// The count of elements in this observable; this is also (efficiently) observable.
    var observableCount: Observable<Int> { get }

    // This is included because although it is not actually required by CollectionType, we do use it in ObservableArray, below.
    subscript(bounds: Range<Int>) -> ArraySlice<Generator.Element> { get }
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
    public typealias Value = [Element]
    public typealias Change = ArrayChange<Element>
    public typealias ObservableValue = [Element]

    public typealias Index = Int
    public typealias Generator = AnyGenerator<Element>
    public typealias SubSequence = Array<Element>.SubSequence

    private let _count: Void->Int
    private let _lookup: Range<Int> -> ArraySlice<Element>
    private let _futureChanges: Void -> Source<ArrayChange<Element>>
    private let _futureValues: Void -> Source<[Element]>

    private var _futureCounts: Source<Int> {
        var connection: Connection? = nil
        let signal = Signal<Int>(
            didConnectFirstSink: { signal in
                connection = self.futureChanges.connect { change in
                    signal.send(change.finalCount)
                }
            },
            didDisconnectLastSink: { signal in
                connection?.disconnect()
                connection = nil
        })
        return signal.source
    }

    public init(count: Void->Int, lookup: Range<Int>->ArraySlice<Element>, futureChanges: Void->Source<ArrayChange<Element>>, futureValues: Void->Source<[Element]>) {
        _count = count
        _lookup = lookup
        _futureChanges = futureChanges
        _futureValues = futureValues
    }

    public init<A: ObservableArrayType where A.Index == Int, A.Generator.Element == Element, A.Change == ArrayChange<Element>>(_ array: A) {
        _count = { array.count }
        _lookup = { range in array[range] }
        _futureChanges = { array.futureChanges }
        _futureValues = { array.futureValues }
    }


    public var value: [Element] { return Array(_lookup(Range(start: 0, end: count))) }
    public var futureChanges: Source<ArrayChange<Element>> { return _futureChanges() }
    public var futureValues: Source<[Element]> { return _futureValues() }

    public var count: Int { return _count() }
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return count }

    public subscript(index: Int) -> Element { return _lookup(Range(start: index, end: index + 1))[index] }
    public subscript(range: Range<Int>) -> ArraySlice<Element> { return _lookup(range) }

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

    // TODO: Move this to an extension of ObservableArrayType once Swift's protocols grow up.
    public var observableCount: Observable<Int> {
        return Observable(getter: { self.count }, futureValues: { self.futureChanges.map { change in change.finalCount } })
    }
}


/// An observable array that is also updatable.
public protocol UpdatableArrayType: UpdatableType, ObservableArrayType, MutableCollectionType, RangeReplaceableCollectionType {
}

public final class ArrayVariable<Element>: UpdatableArrayType, ArrayLiteralConvertible {
    public typealias Change = ArrayChange<Element>
    public typealias ObservableValue = [Element]
    public typealias SinkValue = [Element]

    private var _value: [Element]
    // These are created on demand and released immediately when unused
    private weak var _futureChanges: Signal<ArrayChange<Element>>? = nil
    private weak var _futureValues: Signal<[Element]>? = nil

    public init() {
        _value = []
    }
    public init(_ elements: [Element]) {
        _value = elements
    }
    public init(elements: Element...) {
        _value = elements
    }
    public init(arrayLiteral elements: Element...) {
        _value = elements
    }

    /// The current value of this ArrayVariable.
    public var value: [Element] {
        get { return _value }
        set { setValue(newValue) }
    }

    /// A source that reports all future changes of this variable.
    public var futureChanges: Source<ArrayChange<Element>> {
        if let futureChanges = _futureChanges {
            return futureChanges.source
        }
        else {
            let signal = Signal<ArrayChange<Element>>()
            _futureChanges = signal
            return signal.source
        }
    }

    public var futureValues: Source<[Element]> {
        if let signal = _futureValues {
            return signal.source
        }
        else {
            let s = Signal<[Element]>()
            _futureValues = s
            return s.source
        }
    }

    public func setValue(value: [Element]) {
        let oldCount = _value.count
        _value = value
        _futureChanges?.send(ArrayChange(count: oldCount, modification: .ReplaceRange(0..<oldCount, with: value)))
        _futureValues?.send(value)
    }

    public var count: Int {
        return value.count
    }

    // TODO: Move this to an extension of ObservableArrayType once Swift's protocols grow up.
    public var observableCount: Observable<Int> {
        return Observable(getter: { self.count }, futureValues: { self.futureChanges.map { change in change.finalCount } })
    }
}

extension ArrayVariable: MutableCollectionType {
    public typealias Generator = Array<Element>.Generator
    public typealias SubSequence = Array<Element>.SubSequence

    public var startIndex: Int { return value.startIndex }
    public var endIndex: Int { return value.endIndex }

    public func generate() -> Array<Element>.Generator {
        return value.generate()
    }

    public subscript(index: Int) -> Element {
        get {
            return _value[index]
        }
        set {
            _value[index] = newValue
            _futureChanges?.send(ArrayChange(count: self.count, modification: .ReplaceAt(index, with: newValue)))
            _futureValues?.send(value)
        }
    }

    public subscript(bounds: Range<Int>) -> SubSequence {
        get {
            return value[bounds]
        }
        set {
            let oldCount = count
            _value[bounds] = newValue
            _futureChanges?.send(ArrayChange(count: oldCount, modification: .ReplaceRange(bounds, with: Array<Element>(newValue))))
            _futureValues?.send(value)
        }
    }
}

extension ArrayVariable: RangeReplaceableCollectionType {
    public func replaceRange<C : CollectionType where C.Generator.Element == Generator.Element>(subRange: Range<Int>, with newElements: C) {
        let oldCount = count
        _value.replaceRange(subRange, with: newElements)
        _futureChanges?.send(ArrayChange(count: oldCount, modification: .ReplaceRange(subRange, with: Array<Element>(newElements))))
        _futureValues?.send(value)
    }

    // These have default implementations in terms of replaceRange, but doing them by hand makes for better change reports.

    public func append(newElement: Element) {
        self.insert(newElement, at: self.count)
    }

    public func insert(newElement: Element, at index: Int) {
        _value.insert(newElement, atIndex: index)
        _futureChanges?.send(ArrayChange(count: self.count - 1, modification: .Insert(newElement, at: index)))
        _futureValues?.send(value)
    }

    public func removeAtIndex(index: Int) -> Element {
        let result = _value.removeAtIndex(index)
        _futureChanges?.send(ArrayChange(count: self.count + 1, modification: .RemoveAt(index)))
        _futureValues?.send(value)
        return result
    }

    public func removeFirst() -> Element {
        let result = _value.removeFirst()
        _futureChanges?.send(ArrayChange(count: self.count + 1, modification: .RemoveAt(0)))
        _futureValues?.send(value)
        return result
    }

    public func removeLast() -> Element {
        let result = _value.removeLast()
        _futureChanges?.send(ArrayChange(count: self.count + 1, modification: .RemoveAt(self.count)))
        _futureValues?.send(value)
        return result
    }
    
    public func popLast() -> Element? {
        guard let result = _value.popLast() else { return nil }
        _futureChanges?.send(ArrayChange(count: self.count + 1, modification: .RemoveAt(self.count)))
        _futureValues?.send(value)
        return result
    }

    public func removeAll() {
        let count = _value.count
        _value.removeAll()
        _futureChanges?.send(ArrayChange(count: count, modification: .ReplaceRange(0..<count, with: [])))
        _futureValues?.send(value)
    }
}



