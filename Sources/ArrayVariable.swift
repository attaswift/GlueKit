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
    public typealias Change = ArrayChange<Element>
    public typealias ObservableValue = [Element]
    public typealias SinkValue = [Element]

    private var _value: [Element]
    private var _changeSignal = LazySignal<Change>()
    private var _valueSignal = LazySignal<[Element]>()

    public init() {
        _value = []
    }
    public init(_ elements: [Element]) {
        _value = elements
    }
    public init(elements: Element...) {
        _value = elements
    }

    /// The current value of this ArrayVariable.
    public var value: [Element] {
        get { return _value }
        set { setValue(newValue) }
    }

    /// A source that reports all future changes of this variable.
    public var futureChanges: Source<ArrayChange<Element>> {
        return _changeSignal.source
    }

    public var futureValues: Source<[Element]> {
        return _valueSignal.source
    }

    public func setValue(value: [Element]) {
        let oldCount = _value.count
        _value = value
        _changeSignal.sendIfConnected(ArrayChange(count: oldCount, modification: .ReplaceRange(0..<oldCount, with: value)))
        _valueSignal.sendIfConnected(value)
    }

    public var count: Int {
        return value.count
    }

    public var observableArray: ObservableArray<Element> { return ObservableArray(self) }
    public var updatableArray: UpdatableArray<Element> { return UpdatableArray(self) }

    // TODO: Move this to an extension of ObservableArrayType once Swift's protocols grow up.
    public var observableCount: Observable<Int> {
        return Observable(getter: { self.count }, futureValues: { self.futureChanges.map { change in change.finalCount } })
    }
}

extension ArrayVariable: ArrayLiteralConvertible {
    public convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
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
            _changeSignal.sendIfConnected(ArrayChange(count: self.count, modification: .ReplaceAt(index, with: newValue)))
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
            _changeSignal.sendIfConnected(ArrayChange(count: oldCount, modification: .ReplaceRange(bounds, with: Array<Element>(newValue))))
            _valueSignal.sendIfConnected(value)
        }
    }
}

extension ArrayVariable: RangeReplaceableCollectionType {
    public func replaceRange<C : CollectionType where C.Generator.Element == Generator.Element>(subRange: Range<Int>, with newElements: C) {
        let oldCount = count
        _value.replaceRange(subRange, with: newElements)
        _changeSignal.sendIfConnected(ArrayChange(count: oldCount, modification: .ReplaceRange(subRange, with: Array<Element>(newElements))))
        _valueSignal.sendIfConnected(value)
    }

    // These have default implementations in terms of replaceRange, but doing them by hand makes for better change reports.

    public func append(newElement: Element) {
        self.insert(newElement, at: self.count)
    }

    public func insert(newElement: Element, at index: Int) {
        _value.insert(newElement, atIndex: index)
        _changeSignal.sendIfConnected(ArrayChange(count: self.count - 1, modification: .Insert(newElement, at: index)))
        _valueSignal.sendIfConnected(value)
    }

    public func removeAtIndex(index: Int) -> Element {
        let result = _value.removeAtIndex(index)
        _changeSignal.sendIfConnected(ArrayChange(count: self.count + 1, modification: .RemoveAt(index)))
        _valueSignal.sendIfConnected(value)
        return result
    }

    public func removeFirst() -> Element {
        let result = _value.removeFirst()
        _changeSignal.sendIfConnected(ArrayChange(count: self.count + 1, modification: .RemoveAt(0)))
        _valueSignal.sendIfConnected(value)
        return result
    }

    public func removeLast() -> Element {
        let result = _value.removeLast()
        _changeSignal.sendIfConnected(ArrayChange(count: self.count + 1, modification: .RemoveAt(self.count)))
        _valueSignal.sendIfConnected(value)
        return result
    }
    
    public func popLast() -> Element? {
        guard let result = _value.popLast() else { return nil }
        _changeSignal.sendIfConnected(ArrayChange(count: self.count + 1, modification: .RemoveAt(self.count)))
        _valueSignal.sendIfConnected(value)
        return result
    }

    public func removeAll() {
        let count = _value.count
        _value.removeAll()
        _changeSignal.sendIfConnected(ArrayChange(count: count, modification: .ReplaceRange(0..<count, with: [])))
        _valueSignal.sendIfConnected(value)
    }
}



