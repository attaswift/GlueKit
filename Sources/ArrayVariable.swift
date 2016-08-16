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
    public typealias IndexDistance = Int
    public typealias Indices = CountableRange<Int>
    public typealias Base = Array<Element>
    public typealias Change = ArrayChange<Element>
    public typealias Iterator = Array<Element>.Iterator
    public typealias SubSequence = Array<Element>.SubSequence

    fileprivate var _value: [Element]
    fileprivate var _changeSignal = LazySignal<Change>()
    fileprivate var _valueSignal = LazySignal<[Element]>()

    public init() {
        _value = []
    }
    public init(_ elements: [Element]) {
        _value = elements
    }
    public init<S: Sequence>(_ elements: S) where S.Iterator.Element == Element {
        _value = Array(elements)
    }
    public init(elements: Element...) {
        _value = elements
    }

    // Required members

    public var count: Int {
        return _value.count
    }

    public func lookup(_ range: Range<Int>) -> ArraySlice<Element> {
        return _value[range]
    }

    public func apply(_ change: ArrayChange<Iterator.Element>) {
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

    public func makeIterator() -> Array<Element>.Iterator {
        return value.makeIterator()
    }

    public func setValue(_ value: [Element]) {
        let oldCount = _value.count
        _value = value
        _changeSignal.sendIfConnected(ArrayChange(initialCount: oldCount, modification: .replaceRange(0..<oldCount, with: value)))
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
            _changeSignal.sendIfConnected(ArrayChange(initialCount: self.count, modification: .replaceAt(index, with: newValue)))
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
            _changeSignal.sendIfConnected(ArrayChange(initialCount: oldCount, modification: .replaceRange(bounds.lowerBound ..< bounds.upperBound, with: Array<Element>(newValue))))
            _valueSignal.sendIfConnected(value)
        }
    }

    public var observable: Observable<[Element]> {
        return Observable(getter: { self.value }, futureValues: { self._valueSignal.source })
    }
    public var observableArray: ObservableArray<Element> { return ObservableArray(self) }
    public var updatableArray: UpdatableArray<Element> { return UpdatableArray(self) }
}

extension ArrayVariable: ExpressibleByArrayLiteral {
    public convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension ArrayVariable {
    public func replaceSubrange<C: Collection>(_ subRange: Range<Int>, with newElements: C) where C.Iterator.Element == Iterator.Element {
        let oldCount = count
        _value.replaceSubrange(subRange, with: newElements)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: oldCount,
                                                  modification: .replaceRange(CountableRange(subRange), with: Array<Element>(newElements))))
        _valueSignal.sendIfConnected(value)
    }

    public func append(_ newElement: Element) {
        self.insert(newElement, at: self.count)
    }

    public func append<C: Collection>(contentsOf newElements: C) where C.Iterator.Element == Iterator.Element {
        let oldCount = _value.count
        _value.append(contentsOf: newElements)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: oldCount,
                                                  modification: .replaceRange(oldCount ..< oldCount, with: Array<Element>(newElements))))
        _valueSignal.sendIfConnected(value)
    }

    public func insert(_ newElement: Element, at index: Int) {
        _value.insert(newElement, at: index)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: self.count - 1,
                                                  modification: .insert(newElement, at: index)))
        _valueSignal.sendIfConnected(value)
    }

    public func insert<C: Collection>(contentsOf newElements: C, at i: Int) where C.Iterator.Element == Iterator.Element
    {
        let oldCount = _value.count
        _value.append(contentsOf: newElements)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: oldCount,
                                                  modification: .replaceRange(i ..< i, with: Array<Element>(newElements))))
        _valueSignal.sendIfConnected(value)
    }

    @discardableResult
    public func remove(at index: Int) -> Element {
        let result = _value.remove(at: index)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: self.count + 1,
                                                  modification: .removeAt(index)))
        _valueSignal.sendIfConnected(value)
        return result
    }

    public func removeSubrange(_ subRange: Range<Int>) {
        _value.removeSubrange(subRange)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: _value.count + subRange.count,
                                                  modification: .replaceRange(CountableRange(subRange), with: [])))
    }

    public func removeFirst(_ n: Int) {
        _value.removeFirst(n)
        _changeSignal.sendIfConnected(ArrayChange(initialCount: self.count + n,
                                                  modification: .replaceRange(0..<n, with: [])))
        _valueSignal.sendIfConnected(value)
    }

    @discardableResult
    public func removeFirst() -> Element {
        let result = _value.removeFirst()
        _changeSignal.sendIfConnected(ArrayChange(initialCount: self.count + 1,
                                                  modification: .removeAt(0)))
        _valueSignal.sendIfConnected(value)
        return result
    }

    public func removeAll() {
        let count = _value.count
        _value.removeAll()
        _changeSignal.sendIfConnected(ArrayChange(initialCount: count,
                                                  modification: .replaceRange(0..<count, with: [])))
        _valueSignal.sendIfConnected(value)
    }

    @discardableResult
    public func removeLast() -> Element {
        let result = _value.removeLast()
        _changeSignal.sendIfConnected(ArrayChange(initialCount: self.count + 1,
                                                  modification: .removeAt(self.count)))
        _valueSignal.sendIfConnected(value)
        return result
    }
}



