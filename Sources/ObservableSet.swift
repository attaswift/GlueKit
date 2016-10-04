//
//  ObservableSet.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-12.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

public protocol ObservableSetType {
    associatedtype Element: Hashable
    typealias Base = Set<Element>
    typealias Change = SetChange<Element>

    var isBuffered: Bool { get }
    var count: Int { get }
    var value: Set<Element> { get }
    func contains(_ member: Element) -> Bool
    func isSubset(of other: Set<Element>) -> Bool
    func isSuperset(of other: Set<Element>) -> Bool

    var changes: Source<SetChange<Element>> { get }
    var observable: Observable<Base> { get }
    var observableCount: Observable<Int> { get }
    var observableSet: ObservableSet<Element> { get }
}

extension ObservableSetType {
    public var count: Int { return value.count }
    public func contains(_ member: Element) -> Bool { return value.contains(member) }
    public func isSubset(of other: Set<Element>) -> Bool { return value.isSubset(of: other) }
    public func isSuperset(of other: Set<Element>) -> Bool { return value.isSuperset(of: other) }

    internal var valueChanges: Source<ValueChange<Base>> {
        var value = self.value
        return self.changes.map { (c: Change) -> ValueChange<Base> in
            let old = value
            value.apply(c)
            return ValueChange(from: old, to: value)
        }
    }

    public var observable: Observable<Base> {
        return Observable(getter: { self.value }, changes: { self.valueChanges })
    }

    public var observableCount: Observable<Int> {
        let changes: () -> Source<ValueChange<Int>> = {
            var count = self.count
            return self.changes.map { change in
                let old = count
                count += numericCast(change.inserted.count - change.removed.count)
                return .init(from: old, to: count)
            }
        }
        return Observable(getter: { self.count }, changes: changes)
    }

    public var observableSet: ObservableSet<Element> {
        return ObservableSet(box: ObservableSetBox(self))
    }
}

public struct ObservableSet<Element: Hashable>: ObservableSetType {
    public typealias Base = Set<Element>
    public typealias Change = SetChange<Element>

    let box: ObservableSetBase<Element>

    init(box: ObservableSetBase<Element>) {
        self.box = box
    }

    public init<S: ObservableSetType>(_ set: S) where S.Element == Element {
        self = set.observableSet
    }

    public var isBuffered: Bool { return box.isBuffered }
    public var count: Int { return box.count }
    public var value: Set<Element> { return box.value }
    public func contains(_ member: Element) -> Bool { return box.contains(member) }
    public func isSubset(of other: Set<Element>) -> Bool { return box.isSubset(of: other) }
    public func isSuperset(of other: Set<Element>) -> Bool { return box.isSuperset(of: other) }

    public var changes: Source<SetChange<Element>> { return box.changes }
    public var observable: Observable<Set<Element>> { return box.observable }
    public var observableCount: Observable<Int> { return box.observableCount }

    func holding(_ connection: Connection) -> ObservableSet<Element> { box.hold(connection); return self }
}

class ObservableSetBase<Element: Hashable>: ObservableSetType {
    private var connections: [Connection] = []

    deinit {
        for connection in connections {
            connection.disconnect()
        }
    }

    var isBuffered: Bool { abstract() }
    var count: Int { abstract() }
    var value: Set<Element> { abstract() }
    func contains(_ member: Element) -> Bool { abstract() }
    func isSubset(of other: Set<Element>) -> Bool { abstract() }
    func isSuperset(of other: Set<Element>) -> Bool { abstract() }

    var changes: Source<SetChange<Element>> { abstract() }
    var observable: Observable<Set<Element>> { abstract() }
    var observableCount: Observable<Int> { abstract() }
    final var observableSet: ObservableSet<Element> { return ObservableSet(box: self) }

    final func hold(_ connection: Connection) {
        connections.append(connection)
    }
}

class ObservableSetBox<Contents: ObservableSetType>: ObservableSetBase<Contents.Element> {
    typealias Element = Contents.Element

    let contents: Contents

    init(_ contents: Contents) {
        self.contents = contents
    }

    override var isBuffered: Bool { return contents.isBuffered }
    override var count: Int { return contents.count }
    override var value: Set<Element> { return contents.value }
    override func contains(_ member: Element) -> Bool { return contents.contains(member) }
    override func isSubset(of other: Set<Element>) -> Bool { return contents.isSubset(of: other) }
    override func isSuperset(of other: Set<Element>) -> Bool { return contents.isSuperset(of: other) }

    override var changes: Source<SetChange<Element>> { return contents.changes }
    override var observable: Observable<Set<Element>> { return contents.observable }
    override var observableCount: Observable<Int> { return contents.observableCount }
}

class ObservableConstantSet<Element: Hashable>: ObservableSetBase<Element> {
    let contents: Set<Element>

    init(_ contents: Set<Element>) {
        self.contents = contents
    }

    override var isBuffered: Bool { return true }
    override var count: Int { return contents.count }
    override var value: Set<Element> { return contents }
    override func contains(_ member: Element) -> Bool { return contents.contains(member) }
    override func isSubset(of other: Set<Element>) -> Bool { return contents.isSubset(of: other) }
    override func isSuperset(of other: Set<Element>) -> Bool { return contents.isSuperset(of: other) }

    override var changes: Source<SetChange<Element>> { return Source.empty() }
    override var observable: Observable<Set<Element>> { return Observable.constant(contents) }
    override var observableCount: Observable<Int> { return Observable.constant(contents.count) }
}

extension ObservableSetType {
    public static func constant(_ value: Set<Element>) -> ObservableSet<Element> {
        return ObservableConstantSet(value).observableSet
    }

    public static func emptyConstant() -> ObservableSet<Element> {
        return constant([])
    }
}
