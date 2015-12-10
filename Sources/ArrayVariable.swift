//
//  ArrayVariable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-08.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

//MARK: ArrayModification

internal enum ArrayModification<Element> {
    case Insert(Element, at: Int)
    case RemoveAt(Int)
    case ReplaceAt(Int, with: Element)
    case ReplaceRange(Range<Int>, with: [Element])

    var countDelta: Int {
        switch self {
        case .Insert(_, at: _): return 1
        case .RemoveAt(_): return -1
        case .ReplaceAt(_, with: _): return 0
        case .ReplaceRange(let range, with: let es): return es.count - range.count
        }
    }

    func toRangeReplacement() -> (range: Range<Int>, elements: [Element]) {
        switch self {
        case .Insert(let e, at: let i):
            return (Range(start: i, end: i), [e])
        case .RemoveAt(let i):
            return (Range(start: i, end: i + 1), [])
        case .ReplaceAt(let i, with: let e):
            return (Range(start: i, end: i + 1), [e])
        case .ReplaceRange(let range, with: let es):
            return (range, es)
        }
    }

    func merge(mod: ArrayModification<Element>) -> ArrayModificationMergeResult<Element> {
        let rm1 = self.toRangeReplacement()
        let rm2 = mod.toRangeReplacement()

        if rm1.range.startIndex + rm1.elements.count < rm2.range.startIndex {
            // New range affects indices greater than our range
            return .DisjunctOrderedAfter
        }
        else if rm2.range.endIndex < rm1.range.startIndex {
            // New range affects indices earlier than our range
            return .DisjunctOrderedBefore
        }

        // There is some overlap.
        let delta = rm1.elements.count - rm1.range.count

        let combinedRange = Range<Int>(
            start: min(rm1.range.startIndex, rm2.range.startIndex),
            end: max(rm1.range.endIndex, rm2.range.endIndex - delta)
        )

        let replacement = Range<Int>(
            start: max(0, rm2.range.startIndex - rm1.range.startIndex),
            end: min(rm1.elements.count, rm2.range.endIndex - rm1.range.startIndex))
        var combinedElements = rm1.elements
        combinedElements.replaceRange(replacement, with: rm2.elements)

        switch (combinedRange.count, combinedElements.count) {
        case (0, 0):
            return .CollapsedToNoChange
        case (0, 1):
            return .CollapsedTo(.Insert(combinedElements[0], at: combinedRange.startIndex))
        case (1, 0):
            return .CollapsedTo(.RemoveAt(combinedRange.startIndex))
        case (1, 1):
            return .CollapsedTo(.ReplaceAt(combinedRange.startIndex, with: combinedElements[0]))
        default:
            return .CollapsedTo(.ReplaceRange(combinedRange, with: combinedElements))
        }
    }

    func shift(delta: Int) -> ArrayModification<Element> {
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

internal enum ArrayModificationMergeResult<Element> {
    case DisjunctOrderedBefore
    case DisjunctOrderedAfter
    case CollapsedToNoChange
    case CollapsedTo(ArrayModification<Element>)
}

extension RangeReplaceableCollectionType where Index == Int {
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

//MARK: ArrayChange

public struct ArrayChange<Element>: ChangeType {
    public typealias Value = [Element]

    internal var initialCount: Int
    internal var finalCount: Int

    /// List of independent modifications to apply, in order of startIndex.
    /// All indices are understood to be in the *resulting* array.
    /// (But if you apply them in order to the original, you'll get the correct result.)
    internal var modifications: [ArrayModification<Element>] = []

    internal init(initialCount: Int, finalCount: Int, modifications: [ArrayModification<Element>]) {
        assert(finalCount == initialCount + modifications.reduce(0, combine: { c, m in c + m.countDelta }))
        self.initialCount = initialCount
        self.finalCount = finalCount
        self.modifications = modifications
    }

    internal init(count: Int, modification: ArrayModification<Element>) {
        self.initialCount = count
        self.finalCount = count + modification.countDelta
        self.modifications = [modification]
    }
    public init(from previousValue: Value, to newValue: Value) {
        self.init(count: previousValue.count, modification: .ReplaceRange(0..<previousValue.count, with: newValue))
    }

    public var isNull: Bool { return modifications.isEmpty }

    private mutating func addModification(new: ArrayModification<Element>) {
        finalCount += new.countDelta
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
                modifications[pos] = old.shift(m.countDelta)
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

    public func applyOn(value: [Element]) -> [Element] {
        precondition(value.count == initialCount)
        var result = value
        result.apply(self)
        return result
    }

    public func merge(other: ArrayChange<Element>) -> ArrayChange<Element> {
        precondition(finalCount == other.initialCount)
        var result = self
        for m in other.modifications {
            result.addModification(m)
        }
        assert(result.finalCount == other.finalCount)
        return result
    }
}

extension RangeReplaceableCollectionType where Index == Int {
    public mutating func apply(change: ArrayChange<Generator.Element>) {
        for modification in change.modifications {
            self.apply(modification)
        }
    }
}

public protocol ArrayObservableType: ObservableType {
    var observableCount: Observable<Int> { get }
}

public protocol ArrayUpdatableType: UpdatableType, ArrayObservableType, RangeReplaceableCollectionType {
}

public final class ArrayVariable<Element>: ArrayUpdatableType, ArrayLiteralConvertible {
    public typealias Change = ArrayChange<Element>
    public typealias ObservableValue = [Element]
    public typealias SinkValue = [Element]

    private var _value: [Element]
    // These are created on demand and released immediately when unused
    private weak var _futureChanges: Signal<ArrayChange<Element>>? = nil
    private weak var _futureValues: Signal<[Element]>? = nil
    private weak var _futureCounts: Signal<Int>? = nil

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

    public func setValue(value: [Element]) {
        let oldCount = _value.count
        _value = value
        _futureChanges?.send(ArrayChange(count: oldCount, modification: .ReplaceRange(0..<oldCount, with: value)))
    }

    public var count: Int {
        return value.count
    }

    private var futureCounts: Signal<Int> {
        if let futureCounts = _futureCounts {
            return futureCounts
        }
        else {
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
            _futureCounts = signal
            return signal
        }
    }
    public var observableCount: Observable<Int> {
        return Observable(getter: { self.count }, futureValues: { self.futureCounts.source })
    }

    public var futureValues: Source<[Element]> {
        if let signal = _futureValues {
            return signal.source
        }
        else {
            var connection: Connection? = nil
            let s = Signal<[Element]>(
                didConnectFirstSink: { s in
                    // TODO: check values sent when there're other sinks on self.signal
                    connection = self.futureValues.map { _ in self.value }.connect(s)
                },
                didDisconnectLastSink: { s in
                    connection?.disconnect()
                    connection = nil
            })
            _futureValues = s
            return s.source
        }
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
            return value[index]
        }
        set {
            value[index] = newValue
            _futureChanges?.send(ArrayChange(count: self.count, modification: .ReplaceAt(index, with: newValue)))
        }
    }

    public subscript(bounds: Range<Int>) -> SubSequence {
        get {
            return value[bounds]
        }
        set {
            let oldCount = count
            value[bounds] = newValue
            _futureChanges?.send(ArrayChange(count: oldCount, modification: .ReplaceRange(bounds, with: Array<Element>(newValue))))
        }
    }
}

extension ArrayVariable: RangeReplaceableCollectionType {
    public func replaceRange<C : CollectionType where C.Generator.Element == Generator.Element>(subRange: Range<Int>, with newElements: C) {
        let oldCount = count
        value.replaceRange(subRange, with: newElements)
        _futureChanges?.send(ArrayChange(count: oldCount, modification: .ReplaceRange(subRange, with: Array<Element>(newElements))))
    }

    // These have default implementations in terms of replaceRange, but doing them by hand makes for better change reports.

    public func append(newElement: Element) {
        self.insert(newElement, at: self.count)
    }

    public func insert(newElement: Element, at index: Int) {
        value.insert(newElement, atIndex: index)
        _futureChanges?.send(ArrayChange(count: self.count - 1, modification: .Insert(newElement, at: index)))
    }

    public func removeAtIndex(index: Int) -> Element {
        let result = value.removeAtIndex(index)
        _futureChanges?.send(ArrayChange(count: self.count + 1, modification: .RemoveAt(index)))
        return result
    }

    public func removeFirst() -> Element {
        let result = value.removeFirst()
        _futureChanges?.send(ArrayChange(count: self.count + 1, modification: .RemoveAt(0)))
        return result
    }

    public func removeLast() -> Element {
        let result = value.removeLast()
        _futureChanges?.send(ArrayChange(count: self.count + 1, modification: .RemoveAt(self.count)))
        return result
    }
    
    public func popLast() -> Element? {
        guard let result = value.popLast() else { return nil }
        _futureChanges?.send(ArrayChange(count: self.count + 1, modification: .RemoveAt(self.count)))
        return result
    }

    public func removeAll() {
        let count = value.count
        value.removeAll()
        _futureChanges?.send(ArrayChange(count: count, modification: .ReplaceRange(0..<count, with: [])))
    }
}



