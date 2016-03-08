//
//  ArrayVariable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-08.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

//MARK: ArrayVariable

public final class ArrayVariable<Element>: UpdatableArrayType {
    public typealias Index = Int
    public typealias BaseCollection = Array<Element>
    public typealias Change = ArrayChange<Element>
    public typealias Generator = Array<Element>.Generator
    public typealias SubSequence = Array<Element>.SubSequence

    private var _value: [Element]
    private var _changeSignal = LazySignal<Change>()
    private var _valueSignal = LazySignal<[Element]>()

    public init() {
        _value = []
    }
    public init(_ elements: [Element]) {
        _value = elements
    }
    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        _value = Array(elements)
    }
    public init(elements: Element...) {
        _value = elements
    }

    // Required members

    public var count: Int {
        return _value.count
    }

    public func lookup(range: Range<Int>) -> ArraySlice<Element> {
        return _value[range]
    }

    public func apply(change: ArrayChange<Generator.Element>) {
        guard !change.isEmpty else { return }
        _value.apply(change)
        _changeSignal.sendIfConnected(change)
        _valueSignal.sendIfConnected(value)
    }

    /// A source that reports all future changes of this variable.
    public var futureChanges: Source<ArrayChange<Element>> {
        return _changeSignal.source
    }
}

extension ArrayVariable {
    public var startIndex: Int { return value.startIndex }
    public var endIndex: Int { return value.endIndex }

    public func generate() -> Array<Element>.Generator {
        return value.generate()
    }

    public func setValue(value: [Element]) {
        let oldCount = _value.count
        _value = value
        _changeSignal.sendIfConnected(ArrayChange(initialCount: oldCount, modification: .ReplaceRange(0..<oldCount, with: value)))
        _valueSignal.sendIfConnected(value)
    }

    /// The current value of this ArrayVariable.
    public var value: [Element] {
        get { return _value }
        set { setValue(newValue) }
    }

    public subscript(index: Int) -> Element {
        get {
            return _value[index]
        }
        set {
            _value[index] = newValue
            _changeSignal.sendIfConnected(ArrayChange(initialCount: self.count, modification: .ReplaceAt(index, with: newValue)))
            _valueSignal.sendIfConnected(value)
        }
    }

    public subscript(bounds: Range<Int>) -> SubSequence {
        get {
            return value[bounds]
        }
        set {
            let oldCount = count
            _value[bounds] = newValue
            _changeSignal.sendIfConnected(ArrayChange(initialCount: oldCount, modification: .ReplaceRange(bounds, with: Array<Element>(newValue))))
            _valueSignal.sendIfConnected(value)
        }
    }

    public var observable: Observable<[Element]> {
        return Observable(getter: { self.value }, futureValues: { self._valueSignal.source })
    }
    public var observableArray: ObservableArray<Element> { return ObservableArray(self) }
    public var updatableArray: UpdatableArray<Element> { return UpdatableArray(self) }
}

extension ArrayVariable: ArrayLiteralConvertible {
    public convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension ArrayVariable {
    public func replaceRange<C: CollectionType where C.Generator.Element == Generator.Element>(subRange: Range<Int>, with newElements: C) {
        let oldCount = count
        _value.replaceRange(subRange, with: newElements)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: oldCount, modification: .ReplaceRange(subRange, with: Array<Element>(newElements))))
        _valueSignal.sendIfConnected(value)
    }

    public func append(newElement: Element) {
        self.insert(newElement, at: self.count)
    }

    public func appendContentsOf<C: CollectionType where C.Generator.Element == Generator.Element>(newElements: C) {
        let oldCount = _value.count
        _value.appendContentsOf(newElements)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: oldCount, modification: .ReplaceRange(oldCount ..< oldCount, with: Array<Element>(newElements))))
        _valueSignal.sendIfConnected(value)
    }

    public func insert(newElement: Element, at index: Int) {
        _value.insert(newElement, atIndex: index)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: self.count - 1, modification: .Insert(newElement, at: index)))
        _valueSignal.sendIfConnected(value)
    }

    public func insertContentsOf<C: CollectionType where C.Generator.Element == Generator.Element>(newElements: C, at i: Int)
    {
        let oldCount = _value.count
        _value.appendContentsOf(newElements)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: oldCount, modification: .ReplaceRange(i ..< i, with: Array<Element>(newElements))))
        _valueSignal.sendIfConnected(value)
    }

    public func removeAtIndex(index: Int) -> Element {
        let result = _value.removeAtIndex(index)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: self.count + 1, modification: .RemoveAt(index)))
        _valueSignal.sendIfConnected(value)
        return result
    }

    public func removeRange(subRange: Range<Int>) {
        _value.removeRange(subRange)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: _value.count + subRange.count, modification: .ReplaceRange(subRange, with: [])))
    }

    public func removeFirst(n: Int) {
        _value.removeFirst(n)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: self.count + n, modification: .ReplaceRange(0..<n, with: [])))
        _valueSignal.sendIfConnected(value)
    }

    public func removeFirst() -> Element {
        let result = _value.removeFirst()
        _changeSignal.sendIfConnected(ArrayChange(initialCount: self.count + 1, modification: .RemoveAt(0)))
        _valueSignal.sendIfConnected(value)
        return result
    }

    public func removeAll() {
        let count = _value.count
        _value.removeAll()
        _changeSignal.sendIfConnected(ArrayChange(initialCount: count, modification: .ReplaceRange(0..<count, with: [])))
        _valueSignal.sendIfConnected(value)
    }

    public func removeLast() -> Element {
        let result = _value.removeLast()
        _changeSignal.sendIfConnected(ArrayChange(initialCount: self.count + 1, modification: .RemoveAt(self.count)))
        _valueSignal.sendIfConnected(value)
        return result
    }
}



