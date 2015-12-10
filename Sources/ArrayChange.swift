//
//  ArrayChange.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-10.
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
    public func map<Result>(@noescape transform: Element->Result) -> ArrayModification<Result> {
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
    public func map<Result>(@noescape transform: Element->Result) -> ArrayChange<Result> {
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

