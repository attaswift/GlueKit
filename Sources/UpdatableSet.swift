//
//  UpdatableSet.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-13.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

public protocol UpdatableSetType: ObservableSetType, UpdatableType {
    var value: Base { get nonmutating set }
    func apply(_ change: SetChange<Element>)

    // Optional members
    func remove(_ member: Element)
    func insert(_ member: Element)
    func removeAll()
    func formUnion(_ other: Set<Element>)
    func formIntersection(_ other: Set<Element>)
    func formSymmetricDifference(_ other: Set<Element>)
    func subtract(_ other: Set<Element>)
    
    var updatableSet: UpdatableSet<Element> { get }
}

extension UpdatableSetType {
    public func remove(_ member: Element) {
        // Note: This should be kept in sync with the same member in _AsbtractUpdatableSet.
        if contains(member) {
            apply(SetChange(removed: [member]))
        }
    }

    public func insert(_ member: Element) {
        // Note: This should be kept in sync with the same member in _AsbtractUpdatableSet.
        if !contains(member) {
            apply(SetChange(inserted: [member]))
        }
    }

    public func removeAll() {
        // Note: This should be kept in sync with the same member in _AsbtractUpdatableSet.
        if !isEmpty {
            apply(SetChange(removed: self.value))
        }
    }

    public func formUnion(_ other: Set<Element>) {
        // Note: This should be kept in sync with the same member in _AsbtractUpdatableSet.
        let difference = other.subtracting(value)
        self.apply(SetChange(inserted: difference))
    }

    public func formIntersection(_ other: Set<Element>) {
        // Note: This should be kept in sync with the same member in _AsbtractUpdatableSet.
        let difference = value.subtracting(other)
        self.apply(SetChange(removed: difference))
    }

    public func formSymmetricDifference(_ other: Set<Element>) {
        // Note: This should be kept in sync with the same member in _AsbtractUpdatableSet.
        let value = self.value
        let intersection = value.intersection(other)
        let additions = other.subtracting(value)
        self.apply(SetChange(removed: intersection, inserted: additions))
    }

    public func subtract(_ other: Set<Element>) {
        // Note: This should be kept in sync with the same member in _AsbtractUpdatableSet.
        let intersection = value.intersection(other)
        self.apply(SetChange(removed: intersection))
    }

    public var updatableSet: UpdatableSet<Element> {
        return UpdatableSet(box: UpdatableSetBox(self))
    }
}

public struct UpdatableSet<Element: Hashable>: UpdatableSetType {
    public typealias Value = Set<Element>
    public typealias Base = Set<Element>
    public typealias Change = SetChange<Element>

    let box: _AsbtractUpdatableSet<Element>

    init(box: _AsbtractUpdatableSet<Element>) {
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

    public func withTransaction<Result>(_ body: () -> Result) -> Result { return box.withTransaction(body) }
    public func apply(_ change: SetChange<Element>) { box.apply(change) }
    public func remove(_ member: Element) { box.remove(member) }
    public func insert(_ member: Element) { box.insert(member) }
    public func removeAll() { box.removeAll() }
    public func formUnion(_ other: Set<Element>) { box.formUnion(other) }
    public func formIntersection(_ other: Set<Element>) { box.formIntersection(other) }
    public func formSymmetricDifference(_ other: Set<Element>) { box.formSymmetricDifference(other) }
    public func subtract(_ other: Set<Element>) { box.subtract(other) }

    public var updates: SetUpdateSource<Element> { return box.updates }
    public var observable: Observable<Set<Element>> { return box.observable }
    public var observableCount: Observable<Int> { return box.observableCount }

    public var updatableSet: UpdatableSet<Element> { return self }
}

open class _AsbtractUpdatableSet<Element: Hashable>: _AbstractObservableSet<Element>, UpdatableSetType {
    open override var value: Set<Element> {
        get { abstract() }
        set { abstract() }
    }
    open func withTransaction<Result>(_ body: () -> Result) -> Result { abstract() }
    open func apply(_ change: SetChange<Element>) { abstract() }

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

    public final var updatableSet: UpdatableSet<Element> {
        return UpdatableSet(box: self)
    }
}

class UpdatableSetBox<Contents: UpdatableSetType>: _AsbtractUpdatableSet<Contents.Element> {
    typealias Element = Contents.Element

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

    override func withTransaction<Result>(_ body: () -> Result) -> Result { return contents.withTransaction(body) }
    override func apply(_ change: SetChange<Element>) { contents.apply(change) }

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

    override var updates: SetUpdateSource<Element> { return contents.updates }
    override var observable: Observable<Set<Element>> { return contents.observable }
    override var observableCount: Observable<Int> { return contents.observableCount }
}
