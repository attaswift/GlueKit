//
//  Change.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-12.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

/// Describes a change to an observable value.
/// An instance of a type implementing this protocol contains just enough information to describe the difference
/// between the old value and the new value of the observable.
public protocol ChangeType {
    associatedtype Value

    /// Creates a new change description for a change that goes from `oldValue` to `newValue`.
    init(from oldValue: Value, to newValue: Value)

    /// Returns true if this change did not actually change the value of the observable.
    /// Noop changes aren't usually sent by observables, but it is possible to get them by merging a sequence of
    /// changes to a collection.
    var isEmpty: Bool { get }

    /// Applies this change on `value` in place.
    /// Note that not all changes may be applicable on all values.
    func apply(on value: inout Value)

    /// Applies this change on `value` and returns the result.
    /// Note that not all changes may be applicable on all values.
    func applied(on value: Value) -> Value

    /// Merge this change with the `next` change. The result is a single change description that describes the
    /// change of performing `self` followed by `next`.
    ///
    /// The resulting instance may take a shortcut when producing the result value if some information in `self`
    /// is overwritten by `next`.
    func merged(with next: Self) -> Self

    mutating func merge(with next: Self)

    /// Reverse the direction of this change, i.e., return a change that undoes the effect of this change.
    func reversed() -> Self
}


extension ChangeType {
    /// Applies this change on `value` and returns the result.
    /// Note that not all changes may be applicable on all values.
    public func applied(on value: Value) -> Value {
        var result = value
        self.apply(on: &result)
        return result
    }

    public func merged(with next: Self) -> Self {
        var temp = self
        temp.merge(with: next)
        return temp
    }
}

