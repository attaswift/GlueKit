//
//  UpdatableSet.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-13.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

public protocol UpdatableSetType: ObservableSetType {
    var value: Base { get set }
    func apply(_ change: SetChange<Element>)

    func remove(_ member: Iterator.Element)
    func insert(_ member: Iterator.Element)
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
}

extension UpdatableSetType where Base == Set<Element> {
    public func modify(_ block: (SetVariable<Element>)->Void) {
        let set = SetVariable<Self.Element>(self.value)
        var change = SetChange<Self.Element>()
        let connection = set.futureChanges.connect { c in change.merge(with: c) }
        block(set)
        connection.disconnect()
        self.apply(change)
    }
}

public struct UpdatableSet<Element: Hashable>: UpdatableSetType {
    public typealias Value = Set<Element>
    public typealias Base = Set<Element>
    public typealias Change = SetChange<Element>

    public typealias Index = Base.Index
    public typealias IndexDistance = Int
    public typealias Indices = Base.Indices
    public typealias Iterator = Base.Iterator
    public typealias SubSequence = Base.SubSequence

    public let observableSet: ObservableSet<Element>
    private let _apply: (SetChange<Element>) -> Void

    public init<S: UpdatableSetType>(s: S) where S.Element == Element {
        observableSet = s.observableSet
        _apply = { change in s.apply(change) }
    }

    public var value: Value {
        get { return observableSet.value }
        set { _apply(SetChange(removed: value, inserted: newValue)) }
    }
    public var observableCount: Observable<Int> { return observableSet.observableCount }
    public var observable: Observable<Set<Element>> { return observableSet.observable }
    public var futureChanges: Source<SetChange<Element>> { return observableSet.futureChanges }
    public func apply(_ change: SetChange<Element>) { _apply(change) }

    public static func ==(a: UpdatableSet, b: UpdatableSet) -> Bool { return a.value == b.value }
}
