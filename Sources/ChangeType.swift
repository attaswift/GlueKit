//
//  ChangeType.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-12.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

//MARK: ChangeType

/// Describes a change to an observable that implements a collection of values.
/// An instance of a type implementing this protocol contains just enough information to reproduce the result of the
/// change from the previous value of the observable.
///
/// - SeeAlso: ArrayChange, ObservableArray, ArrayVariable
public protocol ChangeType {
    associatedtype Value

    /// Creates a new change description for a change that goes from `oldValue` to `newValue`.
    init(from oldValue: Value, to newValue: Value)

    /// Returns true if this change did not actually change the value of the observable.
    /// Noop changes aren't usually sent by observables, but it is possible to get them by merging a sequence of
    /// changes to a collection.
    var isEmpty: Bool { get }

    /// Applies this change on `value`, returning the new value.
    /// Note that `value` must be the same value as the one this change was created from.
    func apply(on value: Value) -> Value

    /// Merge this change with the `next` change. The result is a single change description that describes the
    /// change of performing `self` followed by `next`.
    ///
    /// The resulting instance may take a shortcut when producing the result value if some information in `self`
    /// is overwritten by `next`.
    func merged(with next: Self) -> Self
}
