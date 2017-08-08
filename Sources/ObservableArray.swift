//
//  AnyObservableArray.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-11.
//  Copyright © 2015–2017 Károly Lőrentey.
//

public typealias ArrayUpdate<Element> = Update<ArrayChange<Element>>
public typealias ArrayUpdateSource<Element> = AnySource<Update<ArrayChange<Element>>>

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
public protocol ObservableArrayType: ObservableType, CustomReflectable where Change == ArrayChange<Element> {
    associatedtype Element

    // Required methods
    var count: Int { get }
    subscript(bounds: Range<Int>) -> ArraySlice<Element> { get }

    // Extras
    var isBuffered: Bool { get }
    var value: [Element] { get }
    subscript(index: Int) -> Element { get }
    var observableCount: AnyObservableValue<Int> { get }

    var anyObservableValue: AnyObservableValue<[Element]> { get }
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
    internal var valueUpdates: AnySource<ValueUpdate<[Element]>> {
        var value = self.value
        return self.updates.map { event in
            event.map { change in
                let old = value
                value.apply(change)
                return ValueChange(from: old, to: value)
            }
        }.buffered()
    }

    public var anyObservableValue: AnyObservableValue<[Element]> {
        return AnyObservableValue(getter: { self.value }, updates: self.valueUpdates)
    }

    public var observableCount: AnyObservableValue<Int> {
        return AnyObservableValue(getter: { self.count },
                                  updates: self.updates.map { $0.map { $0.countChange } })
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

    public func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<ArrayChange<Element>> {
        box.add(sink)
    }

    @discardableResult
    public func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<ArrayChange<Element>> {
        return box.remove(sink)
    }
    public var observableCount: AnyObservableValue<Int> { return box.observableCount }
    public var anyObservableValue: AnyObservableValue<[Element]> { return box.anyObservableValue }
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

    open func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<ArrayChange<Element>> {
        abstract()
    }

    @discardableResult
    open func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<ArrayChange<Element>> {
        abstract()
    }

    open var observableCount: AnyObservableValue<Int> {
        return AnyObservableValue(getter: { self.count },
                                  updates: self.updates.map { $0.map { $0.countChange } })
    }

    open var anyObservableValue: AnyObservableValue<[Element]> {
        return AnyObservableValue(getter: { self.value }, updates: self.valueUpdates)
    }

    public final var anyObservableArray: AnyObservableArray<Element> { return AnyObservableArray(box: self) }
}

open class _BaseObservableArray<Element>: _AbstractObservableArray<Element>, TransactionalThing {
    var _signal: TransactionalSignal<ArrayChange<Element>>? = nil
    var _transactionCount = 0

    public final override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<ArrayChange<Element>> {
        signal.add(sink)
    }

    @discardableResult
    public final override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<ArrayChange<Element>> {
        return signal.remove(sink)
    }

    open func activate() {
        // Do nothing
    }

    open func deactivate() {
        // Do nothing
    }
}

internal final class ObservableArrayBox<Contents: ObservableArrayType>: _AbstractObservableArray<Contents.Element> {
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
    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<ArrayChange<Element>> {
        contents.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<ArrayChange<Element>> {
        return contents.remove(sink)
    }
    override var observableCount: AnyObservableValue<Int> { return contents.observableCount }
    override var anyObservableValue: AnyObservableValue<[Element]> { return contents.anyObservableValue }
}

internal final class ObservableArrayConstant<Element>: _AbstractObservableArray<Element> {
    let _value: Array<Element>

    init(_ value: [Element]) {
        self._value = value
    }

    override var isBuffered: Bool { return true }
    override subscript(_ index: Int) -> Element { return _value[index] }
    override subscript(_ range: Range<Int>) -> ArraySlice<Element> { return _value[range] }
    override var value: Array<Element> { return _value }
    override var count: Int { return _value.count }
    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<ArrayChange<Element>> {
        // Do nothing
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<ArrayChange<Element>> {
        return sink
    }
    override var observableCount: AnyObservableValue<Int> { return AnyObservableValue.constant(_value.count) }
    override var anyObservableValue: AnyObservableValue<[Element]> { return AnyObservableValue.constant(_value) }
}

extension ObservableArrayType {
    public static func constant(_ value: [Element]) -> AnyObservableArray<Element> {
        return ObservableArrayConstant(value).anyObservableArray
    }

    public static func emptyConstant() -> AnyObservableArray<Element> {
        return constant([])
    }
}
