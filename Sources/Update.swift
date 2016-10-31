//
//  Update.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-26.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

/// Updates are events that describe a change that is happening to an observable.
/// Observables only change inside transactions. A transaction consists three phases, represented
/// by the three cases of this enum type:
///
/// - `beginTransaction` signals the start of a new transaction.
/// - `change` describes a (partial) change to the value of the observable.
///   Each transaction may include any number of such changes.
/// - `endTransaction` closes the transaction.
///
/// While a transaction is in progress, the value of an observable includes all changes that have already been
/// reported in updates.
///
/// Note that is perfectly legal for a transaction to include no actual changes.
public enum Update<Change: ChangeType> {
    /// Hang on, I feel a change coming up.
    case beginTransaction
    /// Here is one change, but I think there might be more coming.
    case change(Change)
    /// OK, I'm done changing.
    case endTransaction
}

extension Update {
    public var change: Change? {
        if case let .change(change) = self { return change }
        return nil
    }

    public func filter(_ test: (Change) -> Bool) -> Update<Change>? {
        switch self {
        case .beginTransaction, .endTransaction:
            return self
        case .change(let change):
            if test(change) {
                return self
            }
            return nil
        }
    }

    public func map<Result: ChangeType>(_ transform: (Change) -> Result) -> Update<Result> {
        switch self {
        case .beginTransaction:
            return .beginTransaction
        case .change(let change):
            return .change(transform(change))
        case .endTransaction:
            return .endTransaction
        }
    }

    public func flatMap<Result: ChangeType>(_ transform: (Change) -> Result?) -> Update<Result>? {
        switch self {
        case .beginTransaction:
            return .beginTransaction
        case .change(let change):
            guard let new = transform(change) else { return nil }
            return .change(new)
        case .endTransaction:
            return .endTransaction
        }
    }

}
