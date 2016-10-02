//
//  ChangeTracking.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-09-03.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension UpdatableArrayType where Element: Equatable {
    /// Return a change trackig variant of this updatable array.
    ///
    /// - SeeAlso: `ChangeTrackingUpdatableArray`, `ChangeTrackingUpdatableSet`
    public func changeTracked() -> ChangeTrackingUpdatableArray<Self> {
        return ChangeTrackingUpdatableArray(base: self)
    }
}

/// An updatable array that remembers what changes were made to it since it was last reset.
/// This can be used to determine if an array was modified since the last save/load operation, and if so,
/// which elements were affected.
///
/// This is not an alternative to `UndoManager`, but it can be used in relation to it.
///
/// The tracked changes exclude modifications where an element was replaced by a value that is equal to it at the same
/// position, so that e.g. undoing a change will count as no change.
///
/// - SeeAlso: `ChangeTrackingUpdatableSet`
public class ChangeTrackingUpdatableArray<Base: UpdatableArrayType>: UpdatableArrayType where Base.Element: Equatable {
    public typealias Element = Base.Element
    public typealias Change = ArrayChange<Element>

    private let base: Base
    private var connection: Connection! = nil

    /// The aggregate changes to this array since the last time `clearPendingChanges()` was called.
    /// These changes do not include cases where an element was changed to a value equal to it at the same position, 
    /// so that e.g. undoing a change will count as no change.
    public private(set) var pendingChanges: Change

    init(base: Base) {
        self.base = base
        self.pendingChanges = Change(initialCount: base.count)
        self.connection = base.changes.connect { [unowned self] change in
            self.pendingChanges = self.pendingChanges.merged(with: change).removingEqualChanges()
        }
    }

    deinit {
        connection.disconnect()
    }

    /// Reset `pendingChanges` to an empty value.
    public func clearPendingChanges() {
        pendingChanges = Change(initialCount: base.count)
    }

    /// Returns true iff the array isn't equal to the value it had the last time `clearPendingChanges` was called.
    public var hasPendingChanges: Bool {
        return !self.pendingChanges.isEmpty
    }

    public var isBuffered: Bool { return base.isBuffered }
    public var value: [Element] {
        get { return base.value }
        set { base.value = value }
    }
    public subscript(index: Int) -> Element {
        get { return base[index] }
        set { base[index] = newValue }
    }
    public subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        get { return base[bounds] }
        set { base[bounds] = newValue }
    }
    public var count: Int { return base.count }
    public var changes: Source<Change> { return base.changes }
    public var observableCount: Observable<Int> { return base.observableCount }
    public var observable: Observable<Array<Element>> { return base.observable }
    public var observableArray: ObservableArray<Element> { return base.observableArray }
    public func modify(_ block: (ArrayVariable<Element>) -> Void) -> Void { base.modify(block) }
    public func apply(_ change: Change) { self.base.apply(change) }
    public var updatable: Updatable<[Element]> { return base.updatable }
    public var updatableArray: UpdatableArray<Element> { return base.updatableArray }
}
