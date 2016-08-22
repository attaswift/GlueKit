//
//  ObservableArray.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-11.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

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
public protocol ObservableArrayType {
    associatedtype Element
    typealias Base = Array<Element>
    typealias Change = ArrayChange<Element>

    // Required methods
    var count: Int { get }
    var value: Base { get }
    var futureChanges: Source<Change> { get }

    var observableCount: Observable<Int> { get }
    var observable: Observable<Base> { get }

    var isBuffered: Bool { get }
    subscript(index: Int) -> Element { get }
    subscript(bounds: Range<Int>) -> ArraySlice<Element> { get }

    // Extras
    var observableArray: ObservableArray<Element> { get }
}

extension ObservableArrayType {
    public subscript(_ index: Int) -> Element {
        return self[index ..< index + 1].first!
    }

    public var observable: Observable<Base> {
        return Observable(
            getter: { return self.value },
            futureValues: {
                var value = self.value
                return self.futureChanges.map { (c: Change) -> Base in
                    value.apply(c)
                    return value
                }
        })
    }

    public var observableCount: Observable<Int> {
        return Observable(getter: { self.count }, futureValues: { self.futureChanges.map { $0.finalCount } })
    }

    public var observableArray: ObservableArray<Element> {
        return ObservableArray(box: ObservableArrayBox(self))
    }
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
    public typealias Base = Array<Element>
    public typealias Change = ArrayChange<Element>

    let box: ObservableArrayBase<Element>

    init(box: ObservableArrayBase<Element>) {
        self.box = box
    }

    public init<A: ObservableArrayType>(_ array: A) where A.Element == Element {
        self = array.observableArray
    }

    public var isBuffered: Bool { return box.isBuffered }
    public subscript(_ index: Int) -> Element { return box[index] }
    public subscript(_ range: Range<Int>) -> ArraySlice<Element> { return box[range] }
    public var value: Array<Element> { return box.value }
    public var count: Int { return box.count }
    public var futureChanges: Source<ArrayChange<Element>> { return box.futureChanges }
    public var observable: Observable<[Element]> { return box.observable }
    public var observableCount: Observable<Int> { return box.observableCount }
    public var observableArray: ObservableArray<Element> { return self }
}

internal class ObservableArrayBase<Element>: ObservableArrayType {
    typealias Base = Array<Element>
    typealias Change = ArrayChange<Element>

    var isBuffered: Bool { abstract() }
    subscript(_ index: Int) -> Element { abstract() }
    subscript(_ range: Range<Int>) -> ArraySlice<Element> { abstract() }
    var value: Array<Element> { abstract() }
    var count: Int { abstract() }
    var futureChanges: Source<ArrayChange<Element>> { abstract() }
    var observableCount: Observable<Int> { abstract() }
    var observable: Observable<[Element]> { abstract() }
    final var observableArray: ObservableArray<Element> { return ObservableArray(box: self) }
}

internal class ObservableArrayBox<Contents: ObservableArrayType>: ObservableArrayBase<Contents.Element> {
    typealias Element = Contents.Element

    let contents: Contents

    init(_ Contents: Contents) {
        self.contents = Contents
    }

    override var isBuffered: Bool { return contents.isBuffered }
    override subscript(_ index: Int) -> Element { return contents[index] }
    override subscript(_ range: Range<Int>) -> ArraySlice<Element> { return contents[range] }
    override var value: Array<Element> { return contents.value }
    override var count: Int { return contents.count }
    override var futureChanges: Source<ArrayChange<Element>> { return contents.futureChanges }
    override var observableCount: Observable<Int> { return contents.observableCount }
    override var observable: Observable<[Element]> { return contents.observable }
}

internal class ObservableArrayConstant<Element>: ObservableArrayBase<Element> {
    let _value: Array<Element>

    init(_ value: [Element]) {
        self._value = value
    }

    override var isBuffered: Bool { return true }
    override subscript(_ index: Int) -> Element { return _value[index] }
    override subscript(_ range: Range<Int>) -> ArraySlice<Element> { return _value[range] }
    override var value: Array<Element> { return _value }
    override var count: Int { return _value.count }
    override var futureChanges: Source<ArrayChange<Element>> { return Source.empty() }
    override var observableCount: Observable<Int> { return Observable.constant(_value.count) }
    override var observable: Observable<[Element]> { return Observable.constant(_value) }
}

extension ObservableArrayType {
    public static func constant(_ value: [Element]) -> ObservableArray<Element> {
        return ObservableArrayConstant(value).observableArray
    }

    public static func emptyConstant() -> ObservableArray<Element> {
        return constant([])
    }
}
