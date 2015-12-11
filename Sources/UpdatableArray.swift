//
//  UpdatableArray.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-11.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

//MARK: UpdatableArrayType

/// An observable array that is also updatable.
public protocol UpdatableArrayType: ObservableArrayType, MutableCollectionType, RangeReplaceableCollectionType {
    var updatableArray: UpdatableArray<Generator.Element> { get }

    nonmutating func replaceRange<C: CollectionType where C.Generator.Element == Generator.Element>(range: Range<Index>, with elements: C)
}

public struct UpdatableArray<Element>: UpdatableArrayType {
    public typealias Value = [Element]
    public typealias Change = ArrayChange<Element>
    public typealias ObservableValue = [Element]

    public typealias Index = Int
    public typealias Generator = AnyGenerator<Element>
    public typealias SubSequence = Array<Element>

    private let _observableArray: ObservableArray<Element>
    private let _store: (Range<Int>, Array<Element>)->Void

    public init() { // Required by RangeReplaceableCollectionType
        let variable = ArrayVariable<Element>()
        _observableArray = ObservableArray(variable)
        _store = { range, elements in variable.replaceRange(range, with: elements) }
    }

    public init(count: Void->Int, lookup: Range<Int>->Array<Element>, store: (Range<Int>, Array<Element>)->Void, futureChanges: Void->Source<ArrayChange<Element>>) {
        _observableArray = ObservableArray(count: count, lookup: lookup, futureChanges: futureChanges)
        _store = store
    }

    public init<A: UpdatableArrayType, S: SequenceType where A.Index == Int, S.Generator.Element == Element, A.Generator.Element == Element, A.Change == ArrayChange<Element>, A.SubSequence == S>(_ array: A) {
        _observableArray = ObservableArray(array)
        _store = { range, elements in array.replaceRange(range, with: elements) }
    }

    public var value: [Element] { return _observableArray.value }
    public var futureChanges: Source<ArrayChange<Element>> { return _observableArray.futureChanges }

    public var count: Int { return _observableArray.count }
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return count }

    public subscript(index: Int) -> Element {
        get {
            return _observableArray[index]
        }
        set(element) {
            _store(Range(start: index, end: index + 1), [element])
        }
    }
    public subscript(range: Range<Int>) -> Array<Element> {
        get {
            return _observableArray[range]
        }
        set(elements) {
            _store(range, elements)
        }
    }

    public func generate() -> AnyGenerator<Element> { return _observableArray.generate() }

    public var observableArray: ObservableArray<Element> { return _observableArray }
    public var updatableArray: UpdatableArray<Element> { return self }

    public var observableCount: Observable<Int> {
        return _observableArray.observableCount
    }

    public nonmutating func replaceRange<C: CollectionType where C.Generator.Element == Element>(range: Range<Index>, with elements: C) {
        _store(range, Array(elements))
    }
}

