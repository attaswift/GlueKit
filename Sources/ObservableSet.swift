//
//  ObservableSet.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-12.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

public typealias SetUpdate<Element: Hashable> = Update<SetChange<Element>>
public typealias SetUpdateSource<Element: Hashable> = Source<SetUpdate<Element>>

public protocol ObservableSetType: ObservableType {
    associatedtype Element: Hashable
    typealias Base = Set<Element>

    var isBuffered: Bool { get }
    var count: Int { get }
    var value: Set<Element> { get }
    func contains(_ member: Element) -> Bool
    func isSubset(of other: Set<Element>) -> Bool
    func isSuperset(of other: Set<Element>) -> Bool

    var updates: SetUpdateSource<Element> { get }
    var observable: Observable<Base> { get }
    var observableCount: Observable<Int> { get }
    var observableSet: ObservableSet<Element> { get }
}

extension ObservableSetType {
    public var isBuffered: Bool { return false }
    public var count: Int { return value.count }
    public func contains(_ member: Element) -> Bool { return value.contains(member) }
    public func isSubset(of other: Set<Element>) -> Bool { return value.isSubset(of: other) }
    public func isSuperset(of other: Set<Element>) -> Bool { return value.isSuperset(of: other) }

    public var isEmpty: Bool { return count == 0 }

    internal var valueUpdates: ValueUpdateSource<Set<Element>> {
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

    internal var countUpdates: ValueUpdateSource<Int> {
        var count = self.count
        return self.updates.map { update in
            update.map { change in
                let old = count
                count += numericCast(change.inserted.count - change.removed.count)
                return .init(from: old, to: count)
            }
        }.buffered()
    }

    public var observableCount: Observable<Int> {
        return Observable(getter: { self.count }, updates: { self.countUpdates })
    }

    public var observableSet: ObservableSet<Element> {
        return ObservableSet(box: ObservableSetBox(self))
    }
}

public struct ObservableSet<Element: Hashable>: ObservableSetType {
    public typealias Base = Set<Element>
    public typealias Change = SetChange<Element>

    let box: _AbstractObservableSet<Element>

    init(box: _AbstractObservableSet<Element>) {
        self.box = box
    }

    public var isBuffered: Bool { return box.isBuffered }
    public var count: Int { return box.count }
    public var value: Set<Element> { return box.value }
    public func contains(_ member: Element) -> Bool { return box.contains(member) }
    public func isSubset(of other: Set<Element>) -> Bool { return box.isSubset(of: other) }
    public func isSuperset(of other: Set<Element>) -> Bool { return box.isSuperset(of: other) }

    public var updates: SetUpdateSource<Element> { return box.updates }
    public var observable: Observable<Set<Element>> { return box.observable }
    public var observableCount: Observable<Int> { return box.observableCount }

    func holding(_ connection: Connection) -> ObservableSet<Element> { box.hold(connection); return self }
}

open class _AbstractObservableSet<Element: Hashable>: ObservableSetType {
    private var connections: [Connection] = []

    deinit {
        for connection in connections {
            connection.disconnect()
        }
    }

    open var value: Set<Element> { abstract() }
    open var updates: SetUpdateSource<Element> { abstract() }

    open var isBuffered: Bool { return false }
    open var count: Int { return value.count }
    open func contains(_ member: Element) -> Bool { return value.contains(member) }
    open func isSubset(of other: Set<Element>) -> Bool { return value.isSubset(of: other) }
    open func isSuperset(of other: Set<Element>) -> Bool { return value.isSuperset(of: other) }

    open var observable: Observable<Set<Element>> { return Observable(getter: { self.value }, updates: { self.valueUpdates }) }
    open var observableCount: Observable<Int> { return Observable(getter: { self.count }, updates: { self.countUpdates }) }

    public final var observableSet: ObservableSet<Element> { return ObservableSet(box: self) }

    public final func hold(_ connection: Connection) {
        connections.append(connection)
    }
}

class ObservableSetBox<Contents: ObservableSetType>: _AbstractObservableSet<Contents.Element> {
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

    override var updates: SetUpdateSource<Element> { return contents.updates }
    override var observable: Observable<Set<Element>> { return contents.observable }
    override var observableCount: Observable<Int> { return contents.observableCount }
}

class ObservableConstantSet<Element: Hashable>: _AbstractObservableSet<Element> {
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

    override var updates: SetUpdateSource<Element> { return Source.empty() }
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
