//
//  UpdatableSet.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-13.
//  Copyright © 2015–2017 Károly Lőrentey.
//

public protocol UpdatableSetType: ObservableSetType, UpdatableType {
    var value: Base { get nonmutating set }
    func apply(_ update: SetUpdate<Element>)

    // Optional members
    func remove(_ member: Element)
    func insert(_ member: Element)
    func removeAll()
    func formUnion(_ other: Set<Element>)
    func formIntersection(_ other: Set<Element>)
    func formSymmetricDifference(_ other: Set<Element>)
    func subtract(_ other: Set<Element>)
    
    var anyUpdatableValue: AnyUpdatableValue<Set<Element>> { get }
    var anyUpdatableSet: AnyUpdatableSet<Element> { get }
}

extension UpdatableSetType {
    public func remove(_ member: Element) {
        // Note: This should be kept in sync with the same member in _AbstractUpdatableSet.
        if contains(member) {
            apply(SetChange(removed: [member]))
        }
    }

    public func insert(_ member: Element) {
        // Note: This should be kept in sync with the same member in _AbstractUpdatableSet.
        if !contains(member) {
            apply(SetChange(inserted: [member]))
        }
    }

    public func removeAll() {
        // Note: This should be kept in sync with the same member in _AbstractUpdatableSet.
        if !isEmpty {
            apply(SetChange(removed: self.value))
        }
    }

    public func formUnion(_ other: Set<Element>) {
        // Note: This should be kept in sync with the same member in _AbstractUpdatableSet.
        let difference = other.subtracting(value)
        self.apply(SetChange(inserted: difference))
    }

    public func formIntersection(_ other: Set<Element>) {
        // Note: This should be kept in sync with the same member in _AbstractUpdatableSet.
        let difference = value.subtracting(other)
        self.apply(SetChange(removed: difference))
    }

    public func formSymmetricDifference(_ other: Set<Element>) {
        // Note: This should be kept in sync with the same member in _AbstractUpdatableSet.
        let value = self.value
        let intersection = value.intersection(other)
        let additions = other.subtracting(value)
        self.apply(SetChange(removed: intersection, inserted: additions))
    }

    public func subtract(_ other: Set<Element>) {
        // Note: This should be kept in sync with the same member in _AbstractUpdatableSet.
        let intersection = value.intersection(other)
        self.apply(SetChange(removed: intersection))
    }

    public func apply(_ update: ValueUpdate<Set<Element>>) {
        self.apply(update.map { change in SetChange(from: change.old, to: change.new) })
    }

    public var anyUpdatableValue: AnyUpdatableValue<Set<Element>> {
        return AnyUpdatableValue(
            getter: { self.value },
            apply: self.apply,
            updates: self.valueUpdates)
    }

    public var anyUpdatableSet: AnyUpdatableSet<Element> {
        return AnyUpdatableSet(box: UpdatableSetBox(self))
    }
}

public struct AnyUpdatableSet<Element: Hashable>: UpdatableSetType {
    public typealias Value = Set<Element>
    public typealias Base = Set<Element>
    public typealias Change = SetChange<Element>

    let box: _AbstractUpdatableSet<Element>

    init(box: _AbstractUpdatableSet<Element>) {
        self.box = box
    }

    public var isBuffered: Bool { return box.isBuffered }
    public var count: Int { return box.count }
    public var value: Set<Element> {
        get { return box.value }
        nonmutating set { box.value = newValue }
    }
    public func contains(_ member: Element) -> Bool { return box.contains(member) }
    public func isSubset(of other: Set<Element>) -> Bool { return box.isSubset(of: other) }
    public func isSuperset(of other: Set<Element>) -> Bool { return box.isSuperset(of: other) }

    public func apply(_ update: SetUpdate<Element>) { box.apply(update) }
    public func remove(_ member: Element) { box.remove(member) }
    public func insert(_ member: Element) { box.insert(member) }
    public func removeAll() { box.removeAll() }
    public func formUnion(_ other: Set<Element>) { box.formUnion(other) }
    public func formIntersection(_ other: Set<Element>) { box.formIntersection(other) }
    public func formSymmetricDifference(_ other: Set<Element>) { box.formSymmetricDifference(other) }
    public func subtract(_ other: Set<Element>) { box.subtract(other) }

    public func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<SetChange<Element>> {
        box.add(sink)
    }

    @discardableResult
    public func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<SetChange<Element>> {
        return box.remove(sink)
    }

    public var observableCount: AnyObservableValue<Int> { return box.observableCount }

    public var anyObservableValue: AnyObservableValue<Set<Element>> { return box.anyObservableValue }
    public var anyObservableSet: AnyObservableSet<Element> { return box.anyObservableSet }
    public var anyUpdatableValue: AnyUpdatableValue<Set<Element>> { return box.anyUpdatableValue }
    public var anyUpdatableSet: AnyUpdatableSet<Element> { return self }
}

open class _AbstractUpdatableSet<Element: Hashable>: _AbstractObservableSet<Element>, UpdatableSetType {
    open override var value: Set<Element> {
        get { abstract() }
        set { abstract() }
    }
    open func apply(_ update: SetUpdate<Element>) { abstract() }

    open func remove(_ member: Element) {
        // Note: This should be kept in sync with the same member in the UpdatableSetType extension above.
        if contains(member) {
            apply(SetChange(removed: [member]))
        }
    }

    open func insert(_ member: Element) {
        // Note: This should be kept in sync with the same member in the UpdatableSetType extension above.
        if !contains(member) {
            apply(SetChange(inserted: [member]))
        }
    }

    open func removeAll() {
        // Note: This should be kept in sync with the same member in the UpdatableSetType extension above.
        if !isEmpty {
            apply(SetChange(removed: self.value))
        }
    }

    open func formUnion(_ other: Set<Element>) {
        // Note: This should be kept in sync with the same member in the UpdatableSetType extension above.
        let difference = other.subtracting(value)
        self.apply(SetChange(inserted: difference))
    }

    open func formIntersection(_ other: Set<Element>) {
        // Note: This should be kept in sync with the same member in the UpdatableSetType extension above.
        let difference = value.subtracting(other)
        self.apply(SetChange(removed: difference))
    }

    open func formSymmetricDifference(_ other: Set<Element>) {
        // Note: This should be kept in sync with the same member in the UpdatableSetType extension above.
        let value = self.value
        let intersection = value.intersection(other)
        let additions = other.subtracting(value)
        self.apply(SetChange(removed: intersection, inserted: additions))
    }

    open func subtract(_ other: Set<Element>) {
        // Note: This should be kept in sync with the same member in the UpdatableSetType extension above.
        let intersection = value.intersection(other)
        self.apply(SetChange(removed: intersection))
    }

    open var anyUpdatableValue: AnyUpdatableValue<Set<Element>> {
        return AnyUpdatableValue(
            getter: { self.value },
            apply: self.apply,
            updates: self.valueUpdates)
    }

    public final var anyUpdatableSet: AnyUpdatableSet<Element> {
        return AnyUpdatableSet(box: self)
    }
}

open class _BaseUpdatableSet<Element: Hashable>: _AbstractUpdatableSet<Element>, TransactionalThing {
    public typealias Change = SetChange<Element>

    var _signal: TransactionalSignal<SetChange<Element>>? = nil
    var _transactionCount: Int = 0

    func rawApply(_ change: Change) { abstract() }

    public final override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        signal.add(sink)
    }

    @discardableResult
    public final override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return signal.remove(sink)
    }

    public final override func apply(_ update: Update<Change>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            rawApply(change)
            sendChange(change)
        case .endTransaction:
            endTransaction()
        }
    }

    open func activate() {
        // Do nothing
    }

    open func deactivate() {
        // Do nothing
    }
}

final class UpdatableSetBox<Contents: UpdatableSetType>: _AbstractUpdatableSet<Contents.Element> {
    typealias Element = Contents.Element
    typealias Change = SetChange<Element>

    let contents: Contents

    init(_ contents: Contents) {
        self.contents = contents
    }

    override var isBuffered: Bool { return contents.isBuffered }
    override var count: Int { return contents.count }

    override var value: Set<Element> {
        get { return contents.value }
        set { contents.value = newValue }
    }

    override func apply(_ update: SetUpdate<Element>) { contents.apply(update) }

    override func remove(_ member: Element) { contents.remove(member) }
    override func insert(_ member: Element) { contents.insert(member) }
    override func removeAll() { contents.removeAll() }
    override func formUnion(_ other: Set<Element>) { contents.formUnion(other) }
    override func formIntersection(_ other: Set<Element>) { contents.formIntersection(other) }
    override func formSymmetricDifference(_ other: Set<Element>) { contents.formSymmetricDifference(other) }
    override func subtract(_ other: Set<Element>) { contents.subtract(other) }

    override func contains(_ member: Element) -> Bool { return contents.contains(member) }
    override func isSubset(of other: Set<Element>) -> Bool { return contents.isSubset(of: other) }
    override func isSuperset(of other: Set<Element>) -> Bool { return contents.isSuperset(of: other) }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        contents.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return contents.remove(sink)
    }

    override var observableCount: AnyObservableValue<Int> { return contents.observableCount }

    override var anyObservableValue: AnyObservableValue<Set<Element>> { return contents.anyObservableValue }
    override var anyUpdatableValue: AnyUpdatableValue<Set<Element>> { return contents.anyUpdatableValue }
}
