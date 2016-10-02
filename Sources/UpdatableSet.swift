//
//  UpdatableSet.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-13.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

public protocol UpdatableSetType: ObservableSetType {
    var value: Base { get nonmutating set }
    func apply(_ change: SetChange<Element>)

    func remove(_ member: Element)
    func insert(_ member: Element)

    var updatableSet: UpdatableSet<Element> { get }
}

extension UpdatableSetType {
    public func remove(_ member: Element) {
        if contains(member) {
            apply(SetChange(removed: [member], inserted: []))
        }
    }

    public func insert(_ member: Element) {
        if !contains(member) {
            apply(SetChange(removed: [], inserted: [member]))
        }
    }

    public var updatableSet: UpdatableSet<Element> {
        return UpdatableSet(box: UpdatableSetBox(self))
    }
}

extension UpdatableSetType {
    public func modify(_ block: (SetVariable<Element>)->Void) {
        let set = SetVariable<Self.Element>(self.value)
        var change = SetChange<Self.Element>()
        let connection = set.changes.connect { c in change.merge(with: c) }
        block(set)
        connection.disconnect()
        self.apply(change)
    }
}

public struct UpdatableSet<Element: Hashable>: UpdatableSetType {
    public typealias Value = Set<Element>
    public typealias Base = Set<Element>
    public typealias Change = SetChange<Element>

    let box: UpdatableSetBase<Element>

    init(box: UpdatableSetBase<Element>) {
        self.box = box
    }

    public init<S: UpdatableSetType>(_ set: S) where S.Element == Element {
        self = set.updatableSet
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

    public func apply(_ change: SetChange<Element>) { box.apply(change) }
    public func remove(_ member: Element) { box.remove(member) }
    public func insert(_ member: Element) { box.insert(member) }

    public var changes: Source<SetChange<Element>> { return box.changes }
    public var observable: Observable<Set<Element>> { return box.observable }
    public var observableCount: Observable<Int> { return box.observableCount }

    public var updatableSet: UpdatableSet<Element> { return self }
}

class UpdatableSetBase<Element: Hashable>: ObservableSetBase<Element>, UpdatableSetType {
    override var value: Set<Element> {
        get { abstract() }
        set { abstract() }
    }
    func apply(_ change: SetChange<Element>) { abstract() }

    func remove(_ member: Element) { abstract() }
    func insert(_ member: Element) { abstract() }

    final var updatableSet: UpdatableSet<Element> { return UpdatableSet(box: self) }
}

class UpdatableSetBox<Contents: UpdatableSetType>: UpdatableSetBase<Contents.Element> {
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

    override func apply(_ change: SetChange<Element>) { contents.apply(change) }

    override func remove(_ member: Element) { contents.remove(member) }
    override func insert(_ member: Element) { contents.insert(member) }

    override func contains(_ member: Element) -> Bool { return contents.contains(member) }
    override func isSubset(of other: Set<Element>) -> Bool { return contents.isSubset(of: other) }
    override func isSuperset(of other: Set<Element>) -> Bool { return contents.isSuperset(of: other) }

    override var changes: Source<SetChange<Element>> { return contents.changes }
    override var observable: Observable<Set<Element>> { return contents.observable }
    override var observableCount: Observable<Int> { return contents.observableCount }
}
