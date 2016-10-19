//
//  ObservableArray.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-11.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public typealias ArrayUpdate<Element> = Update<ArrayChange<Element>>
public typealias ArrayUpdateSource<Element> = Source<ArrayUpdate<Element>>

//MARK: ObservableArrayType

/// An observable array type; i.e., a read-only, array-like observable collection that provides efficient change
/// notifications.
///
/// Changes to an observable array are broadcast as a sequence of `ArrayChange` values, which describe insertions,
/// removals, and replacements.
///
/// Any `ObservableArrayType` can be converted into a type-lifted representation using `ObservableArray`.
/// For a concrete observable array, see `ArrayVariable`.
///
/// - SeeAlso: ObservableValueType, ObservableArray, UpdatableArrayType, ArrayVariable
public protocol ObservableArrayType: ObservableType, CustomReflectable {
    associatedtype Element
    typealias Base = Array<Element>

    // Required methods
    var count: Int { get }
    subscript(bounds: Range<Int>) -> ArraySlice<Element> { get }
    var updates: ArrayUpdateSource<Element> { get }

    // Extras
    var isBuffered: Bool { get }
    var value: Base { get }
    subscript(index: Int) -> Element { get }
    var observableCount: Observable<Int> { get }
    var observable: Observable<Base> { get }
    var observableArray: ObservableArray<Element> { get }
}

extension ObservableArrayType {

    public var customMirror: Mirror {
        return Mirror(self, unlabeledChildren: self.value, displayStyle: .collection)
    }

    public var isBuffered: Bool {
        return false
    }

    public var value: [Element] {
        return Array(self[0 ..< count])
    }

    public subscript(_ index: Int) -> Element {
        return self[index ..< index + 1].first!
    }

    internal var valueUpdates: ValueUpdateSource<[Element]> {
        var value = self.value
        return self.updates.map { event in
            event.map { change in
                let old = value
                value.apply(change)
                return ValueChange(from: old, to: value)
            }
        }.buffered()
    }

    public var observable: Observable<Base> {
        return Observable(getter: { self.value }, updates: { self.valueUpdates })
    }

    public var observableCount: Observable<Int> {
        return Observable(getter: { self.count },
                          updates: { self.updates.map { $0.map { $0.countChange } } })
    }

    public var observableArray: ObservableArray<Element> {
        return ObservableArray(box: ObservableArrayBox(self))
    }

    public var isEmpty: Bool {
        return count == 0
    }
    
    public var first: Element? {
        guard count > 0 else { return nil }
        return self[0]
    }

    public var last: Element? {
        guard count > 0 else { return nil }
        return self[count - 1]
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
/// - SeeAlso: ObservableValueType, ObservableArrayType, UpdatableArrayType, ArrayVariable
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
    public var updates: ArrayUpdateSource<Element> { return box.updates }
    public var observable: Observable<[Element]> { return box.observable }
    public var observableCount: Observable<Int> { return box.observableCount }
    public var observableArray: ObservableArray<Element> { return self }

    func holding(_ connection: Connection) -> ObservableArray<Element> { box.hold(connection); return self }
}

internal class ObservableArrayBase<Element>: ObservableArrayType {
    typealias Base = Array<Element>
    typealias Change = ArrayChange<Element>

    private var connections: [Connection] = []

    deinit {
        for connection in connections {
            connection.disconnect()
        }
    }

    var isBuffered: Bool { abstract() }
    subscript(_ index: Int) -> Element { abstract() }
    subscript(_ range: Range<Int>) -> ArraySlice<Element> { abstract() }
    var value: Array<Element> { abstract() }
    var count: Int { abstract() }
    var updates: ArrayUpdateSource<Element> { abstract() }

    var observableCount: Observable<Int> {
        return Observable(getter: { self.count },
                          updates: { self.updates.map { $0.map { $0.countChange } } })
    }

    var observable: Observable<[Element]> {
        return Observable(getter: { self.value }, updates: { self.valueUpdates })
    }

    final var observableArray: ObservableArray<Element> { return ObservableArray(box: self) }
    final func hold(_ connection: Connection) { connections.append(connection) }
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
    override var updates: ArrayUpdateSource<Element> { return contents.updates }
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
    override var updates: ArrayUpdateSource<Element> { return Source.empty() }
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
