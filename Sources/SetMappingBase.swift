//
//  SetMappingBase.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-05.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

/// An observable set where the value is internally represented as a dictionary of element multiplicities.
/// This class implements the full `ObservableSetType` protocol, and serves as the base class for several transformations
/// on observable sets.
class SetMappingBase<Element: Hashable>: ObservableSetBase<Element> {
    typealias Change = SetChange<Element>

    private(set) var state: [Element: Int] = [:]
    private(set) var signal = OwningSignal<Change>()

    /// Insert `newMember` into `state`, and return true iff it did not previously contain it.
    func insert(_ newMember: Element) -> Bool {
        if let count = state[newMember] {
            state[newMember] = count + 1
            return false
        }
        state[newMember] = 1
        return true
    }

    /// Remove a single instance of `newMember` from `state`, and return true iff this was the last instance.
    /// - Requires: `self.contains(member)`.
    func remove(_ member: Element) -> Bool {
        guard let count = state[member] else {
            fatalError("Inconsistent change: \(member) to be removed is not in result set")
        }
        if count > 1 {
            state[member] = count - 1
            return false
        }
        state.removeValue(forKey: member)
        return true
    }

    final override var isBuffered: Bool { return false }
    final override var count: Int { return state.count }
    final override var value: Set<Element> { return Set(state.keys) }
    final override func contains(_ member: Element) -> Bool { return state[member] != nil }
    final override func isSubset(of other: Set<Element>) -> Bool {
        guard other.count >= state.count else { return false }
        for (key, _) in state {
            guard other.contains(key) else { return false }
        }
        return true
    }

    final override func isSuperset(of other: Set<Element>) -> Bool {
        guard other.count <= state.count else { return false }
        for element in other {
            guard state[element] != nil else { return false }
        }
        return true
    }

    final override var changes: Source<SetChange<Element>> {
        return signal.with(retained: self).source
    }
}
