//
//  ArrayChange.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-10.
//  Copyright © 2015–2017 Károly Lőrentey.
//

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
    case remove(Element, at: Int)
    /// The replacement of a single element at the specified position with the specified new element.
    case replace(Element, at: Int, with: Element)
    /// The replacement of the specified contiguous range of elements with the specified new list of elements.
    /// The count of the range need not equal the replacement element count.
    ///
    /// Note that all other modification cases have an equivalent range replacement.
    /// We chose to keep them separate only because they are more expressive that way.
    case replaceSlice([Element], at: Int, with: [Element])

    /// Convert a contiguous replacement range and a replacement list of elements into a modification.
    public init?(replacing old: [Element], at index: Int, with new: [Element]) {
        switch (old.count, new.count) {
        case (0, 0):
            return nil
        case (0, 1):
            self = .insert(new[0], at: index)
        case (1, 0):
            self = .remove(old[0], at: index)
        case (1, 1):
            self = .replace(old[0], at: index, with: new[0])
        default:
            self = .replaceSlice(old, at: index, with: new)
        }

    }

    /// The effect of this modification on the element count of the array.
    var deltaCount: Int {
        switch self {
        case .insert(_, at: _): return 1
        case .remove(_, at: _): return -1
        case .replace(_, at: _, with: _): return 0
        case .replaceSlice(let old, at: _, with: let new): return new.count - old.count
        }
    }

    public var startIndex: Int {
        switch self {
        case .insert(_, at: let index): return index
        case .remove(_, at: let index): return index
        case .replace(_, at: let index, with: _): return index
        case .replaceSlice(_, at: let index, with: _): return index
        }
    }

    public var inputCount: Int {
        switch self {
        case .insert(_, at: _):
            return 0
        case .remove(_, at: _):
            return 1
        case .replace(_, at: _, with: _):
            return 1
        case .replaceSlice(let old, at: _, with: _):
            return old.count
        }
    }

    public var outputCount: Int {
        switch self {
        case .insert(_, at: _):
            return 1
        case .remove(_, at: _):
            return 0
        case .replace(_, at: _, with: _):
            return 1
        case .replaceSlice(_, at: _, with: let new):
            return new.count
        }
    }

    /// The range (in the original array) that this modification replaces, when converted into a range modification.
    public var inputRange: CountableRange<Int> {
        return startIndex ..< startIndex + inputCount
    }

    /// The range (in the resulting array) that this modification changed.
    public var outputRange: CountableRange<Int> {
        return startIndex ..< startIndex + outputCount
    }

    /// The replacement elements that get inserted by this modification.
    public var newElements: [Element] {
        switch self {
        case .insert(let e, at: _):
            return [e]
        case .remove(_, at: _):
            return []
        case .replace(_, at: _, with: let e):
            return [e]
        case .replaceSlice(_, at: _, with: let es):
            return es
        }
    }

    /// The original elements that this modification removes/changes.
    public var oldElements: [Element] {
        switch self {
        case .insert(_, at: _):
            return []
        case .remove(let e, at: _):
            return [e]
        case .replace(let e, at: _, with: _):
            return [e]
        case .replaceSlice(let es, at: _, with: _):
            return es
        }
    }

    var reversed: ArrayModification<Element> {
        switch self {
        case .insert(let new, at: let index):
            return .remove(new, at: index)
        case .remove(let old, at: let index):
            return .insert(old, at: index)
        case .replace(let old, at: let index, with: let new):
            return .replace(new, at: index, with: old)
        case .replaceSlice(let old, at: let index, with: let new):
            return .replaceSlice(new, at: index, with: old)
        }
    }


    /// Try to merge `mod` into this modification and return the result.
    func merged(with mod: ArrayModification<Element>) -> ArrayModificationMergeResult<Element> {
        let start1 = self.startIndex
        let start2 = mod.startIndex

        let outputCount1 = self.outputCount
        let outputEnd1 = start1 + outputCount1

        let inputCount2 = mod.inputCount
        let inputEnd2 = start2 + inputCount2


        if outputEnd1 < start2 {
            // New range affects indices greater than our range
            return .disjunctOrderedAfter
        }
        if inputEnd2 < start1 {
            // New range affects indices earlier than our range
            return .disjunctOrderedBefore
        }

        // There is some overlap or the ranges are touching each other.
        let combinedStart = min(start1, start2)

        let oldElements2 = mod.oldElements
        var combinedOld = self.oldElements
        if start2 < start1 {
            combinedOld.insert(contentsOf: oldElements2[0 ..< start1 - start2], at: 0)
        }
        let c = inputEnd2 - outputEnd1
        if c > 0 {
            combinedOld.append(contentsOf: oldElements2.suffix(c))
        }

        var combinedNew = self.newElements
        combinedNew.replaceSubrange(max(0, start2 - start1) ..< min(outputCount1, inputEnd2 - start1), with: mod.newElements)

        if let mod = ArrayModification(replacing: combinedOld, at: combinedStart, with: combinedNew) {
            return .collapsedTo(mod)
        }
        return .collapsedToNoChange
    }

    /// Transform each element in this modification using the function `transform`.
    public func map<Result>(_ transform: (Element) -> Result) -> ArrayModification<Result> {
        switch self {
        case .insert(let new, at: let i):
            return .insert(transform(new), at: i)
        case .remove(let old, at: let i):
            return .remove(transform(old), at: i)
        case .replace(let old, at: let i, with: let new):
            return .replace(transform(old), at: i, with: transform(new))
        case .replaceSlice(let old, at: let i, with: let new):
            return .replaceSlice(old.map(transform), at: i, with: new.map(transform))
        }
    }

    /// Call `body` on each old element in this modification.
    public func forEachOldElement(_ body: (Element) -> Void) {
        switch self {
        case .insert(_, at: _):
            break
        case .remove(let old, at: _):
            body(old)
        case .replace(let old, at: _, with: _):
            body(old)
        case .replaceSlice(let old, at: _, with: _):
            old.forEach(body)
        }
    }

    /// Call `body` on each new element in this modification.
    public func forEachNewElement(_ body: (Element) -> Void) {
        switch self {
        case .insert(let new, at: _):
            body(new)
        case .remove(_, at: _):
            break
        case .replace(_, at: _, with: let new):
            body(new)
        case .replaceSlice(_, at: _, with: let new):
            new.forEach(body)
        }
    }


    /// Add the specified delta to all indices in this modification.
    public func shift(_ delta: Int) -> ArrayModification<Element> {
        switch self {
        case .insert(let new, at: let i):
            return .insert(new, at: i + delta)
        case .remove(let old, at: let i):
            return .remove(old, at: i + delta)
        case .replace(let old, at: let i, with: let new):
            return .replace(old, at: i + delta, with: new)
        case .replaceSlice(let old, at: let i, with: let new):
            return .replaceSlice(old, at: i + delta, with: new)
        }
    }
}

extension ArrayModification where Element: Equatable {
    /// Returns an array of modifications that perform the same update as this one, except all cases are removed where
    /// an element is replaced by a value that is equal to it.
    public func removingEqualChanges() -> [ArrayModification] {
        switch self {
        case .insert(_, at: _):
            return [self]
        case .remove(_, at: _):
            return [self]
        case .replace(let old, at: _, with: let new):
            return old == new ? [] : [self]
        case .replaceSlice(let old, at: let index, with: let new):
            var result: [ArrayModification<Element>] = []

            var start = 0
            for i in 0 ..< min(old.count, new.count) {
                if old[i] == new[i] {
                    if start < i {
                        if let mod = ArrayModification(replacing: Array(old[start ..< i]), at: index + start, with: Array(new[start ..< i])) {
                            result.append(mod)
                        }
                    }
                    start = i + 1
                }
            }
            if old.count != new.count || start < old.count {
                if let mod = ArrayModification(replacing: Array(old.suffix(from: start)), at: index + start, with: Array(new.suffix(from: start))) {
                    result.append(mod)
                }
            }
            return result
        }
    }

    /// Returns true iff the result array is equal to the original, i.e. if it doesn't change anything, or only replaces
    /// values with equal values.
    public var isIdentity: Bool {
        switch self {
        case .insert(_, at: _):
            return false
        case .remove(_, at: _):
            return false
        case .replace(let old, at: _, with: let new):
            return old == new
        case .replaceSlice(let old, at: _, with: let new):
            return old == new
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
        case .insert(let new, at: let i):
            return ".insert(\(new), at: \(i))"
        case .remove(let old, at: let i):
            return ".remove(\(old), at: \(i))"
        case .replace(let old, at: let i, with: let new):
            return ".replace(\(old), at: \(i), with: \(new))"
        case .replaceSlice(let old, at: let i, with: let new):
            let oldString = "[\(old.map { "\($0)" }.joined(separator: ", "))]"
            let newString = "[\(new.map { "\($0)" }.joined(separator: ", "))]"
            return ".replaceSlice(\(oldString), at: \(i), with: \(newString))"
        }
    }

    public var debugDescription: String {
        switch self {
        case .insert(let new, at: let i):
            return ".insert(\(String(reflecting: new)), at: \(i))"
        case .remove(let old, at: let i):
            return ".remove(\(String(reflecting: old)), at: \(i))"
        case .replace(let old, at: let i, with: let new):
            return ".replace(\(String(reflecting: old)), at: \(i), with: \(String(reflecting: new)))"
        case .replaceSlice(let old, at: let i, with: let new):
            let oldString = "[\(old.map { String(reflecting: $0) }.joined(separator: ", "))]"
            let newString = "[\(new.map { String(reflecting: $0) }.joined(separator: ", "))]"
            return ".replaceSlice(\(oldString), at: \(i), with: \(newString))"
        }
    }
}

extension ArrayModification: CustomPlaygroundQuickLookable {
    public var customPlaygroundQuickLook: PlaygroundQuickLook {
        return .text(description)
    }
}

extension RangeReplaceableCollection where Index == Int {
    /// Apply `modification` to this array in place.
    public mutating func apply(_ modification: ArrayModification<Iterator.Element>) {
        switch modification {
        case .insert(let element, at: let index):
            self.insert(element, at: index)
        case .remove(_, at: let index):
            self.remove(at: index)
        case .replace(_, at: let index, with: let new):
            self.replaceSubrange(index ..< index + 1, with: [new])
        case .replaceSlice(let old, at: let index, with: let new):
            self.replaceSubrange(index ..< index + old.count, with: new)
        }
    }
}

public func ==<Element: Equatable>(a: ArrayModification<Element>, b: ArrayModification<Element>) -> Bool {
    return a.startIndex == b.startIndex
        && a.inputCount == b.inputCount
        && a.outputCount == b.outputCount
        && a.oldElements == b.oldElements
        && a.newElements == b.newElements
}
public func !=<Element: Equatable>(a: ArrayModification<Element>, b: ArrayModification<Element>) -> Bool {
    return !(a == b)
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
/// - SeeAlso: ArrayModification, AnyObservableArray, ArrayVariable
public struct ArrayChange<Element>: ChangeType {
    public typealias Value = [Element]

    /// The expected initial count of elements in the array on the input of this change.
    public private(set) var initialCount: Int

    /// The expected change in the count of elements in the array as a result of this change.
    public var deltaCount: Int { return modifications.reduce(0) { s, mod in s + mod.deltaCount } }

    public var countChange: ValueChange<Int> { return .init(from: initialCount, to: finalCount) }

    public var finalCount: Int { return initialCount + deltaCount }

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
        if let mod = ArrayModification(replacing: previousValue, at: 0, with: newValue) {
            self.init(initialCount: previousValue.count, modification: mod)
        }
        else {
            self.init(initialCount: previousValue.count)
        }
    }

    /// Returns true if this change contains no actual changes to the array.
    /// This can happen if a series of merged changes cancel each other out---such as the insertion of an element
    /// and the subsequent removal of the same.
    public var isEmpty: Bool { return modifications.isEmpty }

    public mutating func add(_ new: ArrayModification<Element>) {
        var pos = modifications.count - 1
        var m = new
        while pos >= 0 {
            let old = modifications[pos]
            let res = old.merged(with: m)
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

    public func apply(on value: inout Array<Element>) {
        precondition(value.count == initialCount)
        value.apply(self)
    }

    /// Merge `other` into this change, modifying it in place.
    /// `other.initialCount` must be equal to `self.finalCount`, or the merge will report a fatal error.
    public mutating func merge(with other: ArrayChange<Element>) {
        precondition(finalCount == other.initialCount)
        for m in other.modifications {
            add(m)
        }
    }

    /// Returns a new change that contains all changes in this change plus all changes in `other`.
    /// `other.initialCount` must be equal to `self.finalCount`, or the merge will report a fatal error.
    public func merged(with other: ArrayChange<Element>) -> ArrayChange<Element> {
        var result = self
        result.merge(with: other)
        return result
    }

    public func reversed() -> ArrayChange {
        var result = ArrayChange(initialCount: self.finalCount)
        var delta = 0
        for mod in self.modifications {
            result.add(mod.reversed.shift(delta))
            delta -= mod.deltaCount
        }
        return result
    }

    /// Transform all element values contained in this change using the `transform` function.
    public func map<Result>(_ transform: (Element) -> Result) -> ArrayChange<Result> {
        return ArrayChange<Result>(initialCount: initialCount, modifications: modifications.map { $0.map(transform) })
    }

    /// Call `body` on each element value that is removed by this change.
    public func forEachOld(_ body: (Element) -> Void) {
        modifications.forEach { $0.forEachOldElement(body) }
    }

    /// Call `body` on each element value that is added by this change.
    public func forEachNew(_ body: (Element) -> Void) {
        modifications.forEach { $0.forEachNewElement(body) }
    }

    /// Convert this change so that it modifies a range of items in a larger array.
    ///
    /// Modifications contained in the result will be the same as in this change, except they will 
    /// apply on the range `startIndex ..< startIndex + self.initialCount` in the wider array.
    ///
    /// - Parameter startIndex: The start index of the range to rebase this change into.
    /// - Parameter count: The element count of the wider array to rebase this change into.
    /// - Returns: A new change that applies the same modifications on a range inside a wider array.
    public func widen(startIndex: Int, initialCount: Int) -> ArrayChange<Element> {
        precondition(startIndex + self.initialCount <= initialCount)
        if startIndex > 0 {
            let mods = modifications.map { $0.shift(startIndex) }
            return ArrayChange(initialCount: initialCount, modifications: mods)
        }
        else {
            return ArrayChange(initialCount: initialCount, modifications: modifications)
        }
    }
}

extension ArrayChange: CustomStringConvertible {
    public var description: String {
        let type = String(describing: ArrayChange.self)
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
        return Mirror(self, children: ["initialCount": initialCount,
                                       "modifications": modifications],
                      displayStyle: .struct)
    }
}

extension ArrayChange where Element: Equatable {
    public func removingEqualChanges() -> ArrayChange {
        return ArrayChange(initialCount: initialCount, modifications: modifications.flatMap { $0.removingEqualChanges() })
    }
}

public func ==<Element: Equatable>(a: ArrayChange<Element>, b: ArrayChange<Element>) -> Bool {
    return (a.initialCount == b.initialCount
        && a.modifications.elementsEqual(b.modifications, by: ==))
}
public func !=<Element: Equatable>(a: ArrayChange<Element>, b: ArrayChange<Element>) -> Bool {
    return !(a == b)
}

extension RangeReplaceableCollection where Index == Int, IndexDistance == Int {
    /// Apply `change` to this array. The count of self must be the same as the initial count of `change`, or
    /// the operation will report a fatal error.
    public mutating func apply(_ change: ArrayChange<Element>) {
        precondition(self.count == change.initialCount)
        for modification in change.modifications {
            self.apply(modification)
        }
    }
}
