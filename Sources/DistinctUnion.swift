//
//  DistinctUnion.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-04.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableArrayType where Element: Hashable {
    /// Returns an observable set that contains the same elements as this array.
    public func distinctUnion() -> ObservableSet<Element> {
        return DistinctUnion<Self>(self).observableSet
    }
}

private class DistinctUnion<Base: ObservableArrayType>: ObservableSetBase<Base.Element> where Base.Element: Hashable {
    typealias Element = Base.Element

    private var members = Dictionary<Element, Int>()
    private var signal = OwningSignal<SetChange<Element>>()
    private var connection: Connection? = nil

    init(_ base: Base) {
        super.init()
        for element in base.value {
            _ = self.add(element)
        }
        self.connection = base.changes.connect { [unowned self] change in
            var setChange: SetChange<Element>? = self.signal.isConnected ? SetChange<Element>() : nil
            for mod in change.modifications {
                mod.forEachOldElement {
                    if self.remove($0) {
                        setChange?.remove($0)
                    }
                }
                mod.forEachNewElement {
                    if self.add($0) {
                        setChange?.insert($0)
                    }
                }
            }
            if let change = setChange, !change.isEmpty {
                self.signal.send(change)
            }
        }
    }

    private func add(_ element: Element) -> Bool {
        if let old = self.members[element] {
            self.members[element] = old + 1
            return false
        }
        self.members[element] = 1
        return true
    }

    private func remove(_ element: Element) -> Bool {
        let old = self.members[element]!
        if old == 1 {
            self.members[element] = nil
            return true
        }
        self.members[element] = old - 1
        return false
    }

    override var isBuffered: Bool { return true }
    override var count: Int { return value.count }
    override var value: Set<Base.Element> { return Set(members.keys) }
    override func contains(_ element: Base.Element) -> Bool { return members[element] != nil }
    override func isSubset(of other: Set<Base.Element>) -> Bool {
        guard count <= other.count else { return false }
        for (key, _) in members {
            guard other.contains(key) else { return false }
        }
        return true
    }
    override func isSuperset(of other: Set<Base.Element>) -> Bool {
        guard count >= other.count else { return false }
        for element in other {
            guard members[element] != nil else { return false }
        }
        return true
    }

    override var changes: Source<SetChange<Base.Element>> { return signal.with(retained: self).source }
}
