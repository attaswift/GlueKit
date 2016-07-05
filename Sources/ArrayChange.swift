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
    case insert(Element, at: Int)
    /// The removal of a single element at the specified position.
    case removeAt(Int)
    /// The replacement of a single element at the specified position with the specified new element.
    case replaceAt(Int, with: Element)
    /// The replacement of the specified contiguous range of elements with the specified new list of elements.
    /// The count of the range need not equal the replacement element count.
    ///
    /// Note that all other modification cases have an equivalent range replacement.
    /// We chose to keep them separate only because they are more expressive that way.
    case replaceRange(CountableRange<Int>, with: [Element])

    /// Convert a contiguous replacement range and a replacement list of elements into a modification.
    public init(range: CountableRange<Int>, elements: [Element]) {
        switch (range.count, elements.count) {
        case (0, 0):
            self = .replaceRange(range, with: elements) // Well. What can you do
        case (0, 1):
            self = .insert(elements[0], at: range.lowerBound)
        case (1, 0):
            self = .removeAt(range.lowerBound)
        case (1, 1):
            self = .replaceAt(range.lowerBound, with: elements[0])
        default:
            self = .replaceRange(range, with: elements)
        }

    }

    /// The effect of this modification on the element count of the array.
    var deltaCount: Int {
        switch self {
        case .insert(_, at: _): return 1
        case .removeAt(_): return -1
        case .replaceAt(_, with: _): return 0
        case .replaceRange(let range, with: let es): return es.count - range.count
        }
    }

    /// The range (in the original array) that this modification replaces, when converted into a range modification.
    public var range: CountableRange<Int> {
        switch self {
        case .insert(_, at: let i):
            return i ..< i
        case .removeAt(let i):
            return i ..< i + 1
        case .replaceAt(let i, with: _):
            return i ..< i + 1
        case .replaceRange(let range, with: _):
            return range
        }
    }

    /// The replacement elements that this modification inserts into the array in place of the old elements in `range`.
    public var elements: [Element] {
        switch self {
        case .insert(let e, at: _):
            return [e]
        case .removeAt(_):
            return []
        case .replaceAt(_, with: let e):
            return [e]
        case .replaceRange(_, with: let es):
            return es
        }
    }

    /// Try to merge `mod` into this modification and return the result.
    func merge(_ mod: ArrayModification<Element>) -> ArrayModificationMergeResult<Element> {
        let range1 = self.range
        let range2 = mod.range

        let elements1 = self.elements
        let elements2 = mod.elements

        if range1.lowerBound + elements1.count < range2.lowerBound {
            // New range affects indices greater than our range
            return .disjunctOrderedAfter
        }
        else if range2.upperBound < range1.lowerBound {
            // New range affects indices earlier than our range
            return .disjunctOrderedBefore
        }

        // There is some overlap.
        let delta = elements1.count - range1.count

        let combinedRange = min(range1.lowerBound, range2.lowerBound) ..< max(range1.upperBound, range2.upperBound - delta)
        let replacement = max(0, range2.lowerBound - range1.lowerBound) ..< min(elements1.count, range2.upperBound - range1.lowerBound)
        
        var combinedElements = elements1
        combinedElements.replaceSubrange(replacement, with: elements2)

        if combinedRange.count == 0 && combinedElements.count == 0 {
            return .collapsedToNoChange
        }
        else {
            return .collapsedTo(ArrayModification(range: combinedRange, elements: combinedElements))
        }
    }

    /// Transform each element in this modification using the function `transform`.
    public func map<Result>(_ transform: @noescape (Element) -> Result) -> ArrayModification<Result> {
        switch self {
        case .insert(let e, at: let i):
            return .insert(transform(e), at: i)
        case .removeAt(let i):
            return .removeAt(i)
        case .replaceAt(let i, with: let e):
            return .replaceAt(i, with: transform(e))
        case .replaceRange(let range, with: let es):
            return .replaceRange(range, with: es.map(transform))
        }
    }

    /// Call `body` on each element in this modification.
    public func forEach(_ body: @noescape (Element) -> Void) {
        switch self {
        case .insert(let e, at: _):
            body(e)
        case .removeAt(_):
            break
        case .replaceAt(_, with: let e):
            body(e)
        case .replaceRange(_, with: let es):
            es.forEach(body)
        }
    }


    /// Add the specified delta to all indices in this modification.
    public func shift(_ delta: Int) -> ArrayModification<Element> {
        switch self {
        case .insert(let e, at: let i):
            return .insert(e, at: i + delta)
        case .removeAt(let i):
            return .removeAt(i + delta)
        case .replaceAt(let i, with: let e):
            return .replaceAt(i + delta, with: e)
        case .replaceRange(let range, with: let es):
            return .replaceRange(range.lowerBound + delta ..< range.upperBound + delta, with: es)
        }
    }
}

/// The result of an attempt at merging two array modifications.
internal enum ArrayModificationMergeResult<Element> {
    /// The modifications are disjunct, and the new modification changes indexes below the old.
    case disjunctOrderedBefore
    /// The modifications are disjunct, and the new modification changes indexes above the old.
    case disjunctOrderedAfter
    /// The modifications are intersecting, and cancel each other out.
    case collapsedToNoChange
    /// The modifications are intersecting, and merge to the specified new modification.
    case collapsedTo(ArrayModification<Element>)
}

extension ArrayModification: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        switch self {
        case .insert(let e, at: let i):
            return ".insert(\(String(reflecting: e)), at: \(i))"
        case .removeAt(let i):
            return ".removeAt(\(i))"
        case .replaceAt(let i, with: let e):
            return ".replaceAt(\(i), with: \(String(reflecting: e)))"
        case .replaceRange(let range, with: let es):
            return ".replaceRange(\(range.lowerBound)..<\(range.upperBound), with: [\(es.map { String(reflecting: $0) }.joined(separator: ", "))])"
        }
    }

    public var debugDescription: String { return description }
}

extension RangeReplaceableCollection where Index == Int {
    /// Apply `modification` to this array in place.
    public mutating func apply(_ modification: ArrayModification<Iterator.Element>, add: @noescape (Iterator.Element) -> Void = { _ in }, remove: @noescape (Iterator.Element) -> Void = { _ in }) {
        switch modification {
        case .insert(let element, at: let index):
            self.insert(element, at: index)
            add(element)
        case .removeAt(let index):
            remove(self[index])
            self.remove(at: index)
        case .replaceAt(let index, with: let element):
            remove(self[index])
            self.replaceSubrange(index ..< index + 1, with: [element])
            add(element)
        case .replaceRange(let range, with: let elements):
            range.forEach { remove(self[$0]) }
            self.replaceSubrange(range, with: elements)
            elements.forEach { add($0) }
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

    /// The expected change in the count of elements in the array as a result of this change.
    public var deltaCount: Int { return modifications.reduce(0) { s, mod in s + mod.deltaCount } }

    /// The sequence of independent modifications to apply, in order of the start indexes of their ranges.
    /// All indices are understood to be in the array resulting from the original array by applying all
    /// earlier modifications. (So you can simply loop over the modifications and apply them one by one.)
    public private(set) var modifications: [ArrayModification<Element>] = []

    public init(initialCount: Int) {
        self.initialCount = initialCount
        self.modifications = []
    }

    internal init(initialCount: Int, modifications: [ArrayModification<Element>]) {
        self.initialCount = initialCount
        self.modifications = modifications
    }

    /// Initializes a change with `count` as the expected initial count and consisting of `modification`.
    public init(initialCount: Int, modification: ArrayModification<Element>) {
        self.initialCount = initialCount
        self.modifications = [modification]
    }

    /// Initializes a change that simply replaces all elements in `previousValue` with the ones in `newValue`.
    public init(from previousValue: Value, to newValue: Value) {
        // Elements aren't necessarily equatable here, so this is the best we can do.
        self.init(initialCount: previousValue.count, modification: .replaceRange(0..<previousValue.count, with: newValue))
    }

    /// Returns true if this change contains no actual changes to the array.
    /// This can happen if a series of merged changes cancel each other out---such as the insertion of an element
    /// and the subsequent removal of the same.
    public var isEmpty: Bool { return modifications.isEmpty }

    public mutating func addModification(_ new: ArrayModification<Element>) {
        var pos = modifications.count - 1
        var m = new
        while pos >= 0 {
            let old = modifications[pos]
            let res = old.merge(m)
            switch res {
            case .disjunctOrderedAfter:
                modifications.insert(m, at: pos + 1)
                return
            case .disjunctOrderedBefore:
                modifications[pos] = old.shift(m.deltaCount)
                pos -= 1
                continue
            case .collapsedToNoChange:
                modifications.remove(at: pos)
                return
            case .collapsedTo(let merged):
                modifications.remove(at: pos)
                m = merged
                pos -= 1
                continue
            }
        }
        modifications.insert(m, at: 0)
    }

    /// Apply this change on `value`, which must have a count equal to the `initialCount` of this change.
    public func applyOn(_ value: [Element]) -> [Element] {
        precondition(value.count == initialCount)
        var result = value
        result.apply(self)
        return result
    }

    /// Merge `other` into this change, modifying it in place.
    /// `other.initialCount` must be equal to `self.finalCount`, or the merge will report a fatal error.
    public mutating func mergeInPlace(_ other: ArrayChange<Element>) {
        precondition(initialCount + deltaCount == other.initialCount)
        for m in other.modifications {
            addModification(m)
        }
    }

    /// Returns a new change that contains all changes in this change plus all changes in `other`.
    /// `other.initialCount` must be equal to `self.finalCount`, or the merge will report a fatal error.
    public func merge(_ other: ArrayChange<Element>) -> ArrayChange<Element> {
        var result = self
        result.mergeInPlace(other)
        return result
    }

    /// Transform all element values contained in this change using the `transform` function.
    public func map<Result>(_ transform: @noescape (Element) -> Result) -> ArrayChange<Result> {
        return ArrayChange<Result>(initialCount: initialCount, modifications: modifications.map { $0.map(transform) })
    }

    /// Call `body` on each element value contained in this change.
    public func forEach(_ body: @noescape (Element) -> Void) {
        modifications.forEach { $0.forEach(body) }
    }

    /// Convert this change so that it modifies a range of items in a larger array.
    ///
    /// Modifications contained in the result will be the same as in this change, except they will 
    /// apply on the range `startIndex ..< startIndex + self.initialCount` in the wider array.
    ///
    /// - Parameter startIndex: The start index of the range to rebase this change into.
    /// - Parameter count: The element count of the wider array to rebase this change into.
    /// - Returns: A new change that applies the same modifications on a range inside a wider array.
    public func widen(_ startIndex: Int, count: Int) -> ArrayChange<Element> {
        precondition(startIndex + initialCount <= count)
        let mods = modifications.map { $0.shift(startIndex) }
        return ArrayChange(initialCount: count, modifications: mods)
    }

    /// Return the set of indices at which elements will be deleted from the array when this change is applied.
    /// This is intended to be given to a `UITableView` inside a `beginUpdates` block.
    public var deletedIndices: NSIndexSet {
        let result = NSMutableIndexSet()
        var delta = 0
        for modification in modifications {
            switch modification {
            case .insert(_, at: _):
                break
            case .removeAt(let index):
                result.add(index - delta)
            case .replaceAt(_, with: _):
                break
            case .replaceRange(let indices, with: let elements):
                if elements.count < indices.count {
                    result.add(in: NSRange(indices.lowerBound + elements.count - delta ..< indices.upperBound - delta))
                }
            }
            delta += modification.deltaCount
        }
        return result
    }

    /// Return the set of indices at which elements will be replaced in the array when this change is applied.
    /// The returned indices assume deletions were already done, but not insertions.
    /// This is intended to be given to a `UITableView` inside a `beginUpdates` block.
    public var reloadedIndices: NSIndexSet {
        let result = NSMutableIndexSet()
        var delta = 0
        for modification in modifications {
            switch modification {
            case .insert(_, at: _):
                delta += modification.deltaCount
            case .removeAt(_):
                break
            case .replaceAt(let index, with: _):
                result.add(index - delta)
                break
            case .replaceRange(let indices, with: let elements):
                let commonCount = min(elements.count, indices.count)
                if commonCount > 0 {
                    result.add(in: NSRange(indices.lowerBound - delta ..< indices.lowerBound + commonCount - delta))
                }
                if commonCount < indices.count {
                    delta += modification.deltaCount
                }
            }
        }
        return result
    }

    /// Return the set of indices at which elements will be inserted in the array when this change is applied.
    /// The returned indices assume deletions were already done.
    /// This is intended to be given to a `UITableView` inside a `beginUpdates` block.
    public var insertedIndices: NSIndexSet {
        let result = NSMutableIndexSet()
        for modification in modifications {
            switch modification {
            case .insert(_, at: let index):
                result.add(index)
            case .removeAt(_):
                break
            case .replaceAt(_, with: _):
                break
            case .replaceRange(let indices, with: let elements):
                if indices.count < elements.count {
                    result.add(in: NSRange(indices.lowerBound + elements.count ..< indices.upperBound))
                }
            }
        }
        return result
    }
}

extension ArrayChange: CustomStringConvertible {
    public var description: String {
        let type = String(ArrayChange.self)
        let c = modifications.count
        return "\(type) initialCount: \(initialCount), \(c) modifications"
    }
}

extension ArrayChange: CustomDebugStringConvertible {
    public var debugDescription: String {
        let type = String(reflecting: ArrayChange.self)
        let c = modifications.count
        return "\(type) initialCount: \(initialCount), \(c) modifications"
    }
}

extension ArrayChange: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self, unlabeledChildren: modifications, displayStyle: .struct)
    }
}

public func ==<Element: Equatable>(a: ArrayChange<Element>, b: ArrayChange<Element>) -> Bool {
    return (a.initialCount == b.initialCount
        && a.modifications.elementsEqual(b.modifications, isEquivalent: ==))
}

extension RangeReplaceableCollection where Index == Int, IndexDistance == Int {
    /// Apply `change` to this array. The count of self must be the same as the initial count of `change`, or
    /// the operation will report a fatal error.
    public mutating func apply(_ change: ArrayChange<Generator.Element>, add: @noescape (Iterator.Element) -> Void = { _ in }, remove: @noescape (Generator.Element) -> Void = { _ in }) {
        precondition(self.count == change.initialCount)
        for modification in change.modifications {
            self.apply(modification, add: add, remove: remove)
        }
    }
}
