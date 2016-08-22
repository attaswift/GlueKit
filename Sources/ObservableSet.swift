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

    var futureChanges: Source<SetChange<Element>> { get }
    var observable: Observable<Base> { get }
    var observableCount: Observable<Int> { get }
    var observableSet: ObservableSet<Element> { get }
}

extension ObservableSetType {
    public var count: Int { return value.count }
    public func contains(_ member: Element) -> Bool { return value.contains(member) }
    public func isSubset(of other: Set<Element>) -> Bool { return value.isSubset(of: other) }
    public func isSuperset(of other: Set<Element>) -> Bool { return value.isSuperset(of: other) }

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
        let fv: () -> Source<Int> = {
            var count = self.count
            return self.futureChanges.map { change in
                count += numericCast(change.inserted.count - change.removed.count)
                return count
            }
        }
        return Observable(
            getter: { self.count },
            futureValues: fv)
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

    public var futureChanges: Source<SetChange<Element>> { return box.futureChanges }
    public var observable: Observable<Set<Element>> { return box.observable }
    public var observableCount: Observable<Int> { return box.observableCount }
}

class ObservableSetBase<Element: Hashable>: ObservableSetType {
    var isBuffered: Bool { abstract() }
    var count: Int { abstract() }
    var value: Set<Element> { abstract() }
    func contains(_ member: Element) -> Bool { abstract() }
    func isSubset(of other: Set<Element>) -> Bool { abstract() }
    func isSuperset(of other: Set<Element>) -> Bool { abstract() }

    var futureChanges: Source<SetChange<Element>> { abstract() }
    var observable: Observable<Set<Element>> { abstract() }
    var observableCount: Observable<Int> { abstract() }
    final var observableSet: ObservableSet<Element> { return ObservableSet(box: self) }
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

    override var futureChanges: Source<SetChange<Element>> { return contents.futureChanges }
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

    override var futureChanges: Source<SetChange<Element>> { return Source.empty() }
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
