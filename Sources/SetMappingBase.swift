//
//  SetMappingBase.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-05.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

/// An observable set where the value is internally represented as a dictionary of element multiplicities.
/// This class implements the full `ObservableSetType` protocol, and serves as the base class for several transformations
/// on observable sets.
class SetMappingBase<Element: Hashable>: _BaseObservableSet<Element> {
    typealias Change = SetChange<Element>

    private(set) var contents: [Element: Int] = [:]

    /// Insert `newMember` into `state`, and return true iff it did not previously contain it.
    final func insert(_ newMember: Element) -> Bool {
        if let count = contents[newMember] {
            contents[newMember] = count + 1
            return false
        }
        contents[newMember] = 1
        return true
    }

    /// Remove a single instance of `newMember` from `state`, and return true iff this was the last instance.
    /// - Requires: `self.contains(member)`.
    final func remove(_ member: Element) -> Bool {
        guard let count = contents[member] else {
            fatalError("Inconsistent change: \(member) to be removed is not in result set")
        }
        if count > 1 {
            contents[member] = count - 1
            return false
        }
        contents.removeValue(forKey: member)
        return true
    }

    final override var isBuffered: Bool { return false }
    final override var count: Int { return contents.count }
    final override var value: Set<Element> { return Set(contents.keys) }
    final override func contains(_ member: Element) -> Bool { return contents[member] != nil }
    
    final override func isSubset(of other: Set<Element>) -> Bool {
        guard other.count >= contents.count else { return false }
        for (key, _) in contents {
            guard other.contains(key) else { return false }
        }
        return true
    }

    final override func isSuperset(of other: Set<Element>) -> Bool {
        guard other.count <= contents.count else { return false }
        for element in other {
            guard contents[element] != nil else { return false }
        }
        return true
    }
}
