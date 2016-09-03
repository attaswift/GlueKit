//
//  ChangeTrackingSet.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-09-03.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension UpdatableSetType {
    /// Return a change trackig variant of this updatable set.
    ///
    /// - SeeAlso: `ChangeTrackingUpdatableSet`, `ChangeTrackingUpdatableArray`
    public func changeTracked() -> ChangeTrackingUpdatableSet<Self> {
        return ChangeTrackingUpdatableSet(base: self)
    }
}

/// An updatable set that remembers what changes were made to it since it was last reset.
/// This can be used to determine if a set was modified since the last save/load operation, and if so,
/// which elements were affected.
///
/// This is not an alternative to `UndoManager`, but it can be used in relation to it.
///
/// The tracked changes exclude modifications where an element was replaced by a value that is equal to it, so that
/// e.g. undoing a change will count as no change.
///
/// - SeeAlso: `ChangeTrackingUpdatableArray`
public class ChangeTrackingUpdatableSet<Base: UpdatableSetType>: UpdatableSetType {
    public typealias Element = Base.Element
    public typealias Change = SetChange<Element>

    private let base: Base

    /// The aggregate changes to this set since the last time `clearPendingChanges()` was called.
    /// These changes do not include cases where an element was changed to a value equal to it,
    /// so that e.g. undoing a change will count as no change.
    public private(set) var pendingChanges: Change

    private var connection: Connection! = nil

    public init(base: Base) {
        self.base = base
        self.pendingChanges = Change()
        self.connection = base.futureChanges.connect { [unowned self] change in
            self.pendingChanges = self.pendingChanges.merged(with: change).removingEqualChanges()
        }
    }

    deinit {
        connection.disconnect()
    }

    /// Reset `pendingChanges` to an empty value.
    public func clearPendingChanges() {
        self.pendingChanges = Change()
    }

    public var isBuffered: Bool { return base.isBuffered }
    public var count: Int { return base.count }

    public var value: Set<Element> {
        get { return base.value }
        set { base.value = newValue }
    }

    public func apply(_ change: SetChange<Element>) { base.apply(change) }

    public func remove(_ member: Element) { base.remove(member) }
    public func insert(_ member: Element) { base.insert(member) }

    public func contains(_ member: Element) -> Bool { return base.contains(member) }
    public func isSubset(of other: Set<Element>) -> Bool { return base.isSubset(of: other) }
    public func isSuperset(of other: Set<Element>) -> Bool { return base.isSuperset(of: other) }

    public var futureChanges: Source<SetChange<Element>> { return base.futureChanges }
    public var observable: Observable<Set<Element>> { return base.observable }
    public var observableCount: Observable<Int> { return base.observableCount }

}
