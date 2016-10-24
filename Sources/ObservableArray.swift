//
//  AnyObservableArray.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-11.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

public typealias ArrayUpdate<Element> = Update<ArrayChange<Element>>
public typealias ArrayUpdateSource<Element> = AnySource<ArrayUpdate<Element>>

//MARK: ObservableArrayType

/// An observable array type; i.e., a read-only, array-like observable collection that provides efficient change
/// notifications.
///
/// Changes to an observable array are broadcast as a sequence of `ArrayChange` values, which describe insertions,
/// removals, and replacements.
///
/// Any `ObservableArrayType` can be converted into a type-erased representation using `AnyObservableArray`.
/// For a concrete observable array, see `ArrayVariable`.
///
/// - SeeAlso: ObservableValueType, AnyObservableArray, UpdatableArrayType, ArrayVariable
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
    var observableCount: AnyObservableValue<Int> { get }

    var anyObservable: AnyObservableValue<Base> { get }
    var anyObservableArray: AnyObservableArray<Element> { get }
}

extension ObservableArrayType {
    public var isBuffered: Bool {
        return false
    }

    public var value: [Element] {
        return Array(self[0 ..< count])
    }

    public subscript(_ index: Int) -> Element {
        return self[index ..< index + 1].first!
    }
}

extension ObservableArrayType {
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

    public var anyObservable: AnyObservableValue<Base> {
        return AnyObservableValue(getter: { self.value }, updates: { self.valueUpdates })
    }

    public var observableCount: AnyObservableValue<Int> {
        return AnyObservableValue(getter: { self.count },
                                  updates: { self.updates.map { $0.map { $0.countChange } } })
    }

    public var anyObservableArray: AnyObservableArray<Element> {
        return AnyObservableArray(box: ObservableArrayBox(self))
    }
}

extension ObservableArrayType {
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

extension ObservableArrayType {
    public var customMirror: Mirror {
        return Mirror(self, unlabeledChildren: self.value, displayStyle: .collection)
    }
}

/// An observable array type; i.e., a read-only, array-like `CollectionType` that also provides efficient change
/// notifications.
///
/// Changes to an observable array are broadcast as a sequence of `ArrayChange` values, which describe insertions,
/// removals, and replacements.
/// The count of elements in an `ObservableArrayType` is itself observable via its `observableCount` property.
///
/// Any `ObservableArrayType` can be converted into a type-erased representation using `AnyObservableArray`.
/// For a concrete observable array, see `ArrayVariable`.
///
/// - SeeAlso: ObservableValueType, ObservableArrayType, UpdatableArrayType, ArrayVariable
public struct AnyObservableArray<Element>: ObservableArrayType {
    public typealias Base = Array<Element>
    public typealias Change = ArrayChange<Element>

    let box: _AbstractObservableArray<Element>

    init(box: _AbstractObservableArray<Element>) {
        self.box = box
    }

    public init<A: ObservableArrayType>(_ array: A) where A.Element == Element {
        self = array.anyObservableArray
    }

    public var isBuffered: Bool { return box.isBuffered }
    public subscript(_ index: Int) -> Element { return box[index] }
    public subscript(_ range: Range<Int>) -> ArraySlice<Element> { return box[range] }
    public var value: Array<Element> { return box.value }
    public var count: Int { return box.count }
    public var updates: ArrayUpdateSource<Element> { return box.updates }
    public var observableCount: AnyObservableValue<Int> { return box.observableCount }
    public var anyObservable: AnyObservableValue<[Element]> { return box.anyObservable }
    public var anyObservableArray: AnyObservableArray<Element> { return self }
}

open class _AbstractObservableArray<Element>: ObservableArrayType {
    public typealias Base = Array<Element>
    public typealias Change = ArrayChange<Element>

    open var isBuffered: Bool { abstract() }
    open subscript(_ index: Int) -> Element { abstract() }
    open subscript(_ range: Range<Int>) -> ArraySlice<Element> { abstract() }
    open var value: Array<Element> { abstract() }
    open var count: Int { abstract() }
    open var updates: ArrayUpdateSource<Element> { abstract() }

    open var observableCount: AnyObservableValue<Int> {
        return AnyObservableValue(getter: { self.count },
                                  updates: { self.updates.map { $0.map { $0.countChange } } })
    }

    open var anyObservable: AnyObservableValue<[Element]> {
        return AnyObservableValue(getter: { self.value }, updates: { self.valueUpdates })
    }

    public final var anyObservableArray: AnyObservableArray<Element> { return AnyObservableArray(box: self) }
}

open class _BaseObservableArray<Element>: _AbstractObservableArray<Element>, LazyObserver {
    private var state = TransactionState<_BaseObservableArray, ArrayChange<Element>>()

    public final override var updates: ArrayUpdateSource<Element> {
        return state.source(retaining: self)
    }

    final var isConnected: Bool {
        return state.isConnected
    }

    final func beginTransaction() {
        state.begin()
    }

    final func endTransaction() {
        state.end()
    }

    final func sendChange(_ change: Change) {
        state.send(change)
    }

    open func startObserving() {
        // Do nothing
    }

    open func stopObserving() {
        // Do nothing
    }
}

internal class ObservableArrayBox<Contents: ObservableArrayType>: _AbstractObservableArray<Contents.Element> {
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
    override var observableCount: AnyObservableValue<Int> { return contents.observableCount }
    override var anyObservable: AnyObservableValue<[Element]> { return contents.anyObservable }
}

internal class ObservableArrayConstant<Element>: _AbstractObservableArray<Element> {
    let _value: Array<Element>

    init(_ value: [Element]) {
        self._value = value
    }

    override var isBuffered: Bool { return true }
    override subscript(_ index: Int) -> Element { return _value[index] }
    override subscript(_ range: Range<Int>) -> ArraySlice<Element> { return _value[range] }
    override var value: Array<Element> { return _value }
    override var count: Int { return _value.count }
    override var updates: ArrayUpdateSource<Element> { return AnySource.empty() }
    override var observableCount: AnyObservableValue<Int> { return AnyObservableValue.constant(_value.count) }
    override var anyObservable: AnyObservableValue<[Element]> { return AnyObservableValue.constant(_value) }
}

extension ObservableArrayType {
    public static func constant(_ value: [Element]) -> AnyObservableArray<Element> {
        return ObservableArrayConstant(value).anyObservableArray
    }

    public static func emptyConstant() -> AnyObservableArray<Element> {
        return constant([])
    }
}
