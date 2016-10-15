//
//  ObservableState.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-14.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

internal struct ObservableState<Change: ChangeType> {
    private var pendingCount = 0
    private var pendingChange: Change? = nil

    mutating func applyEvent(_ event: ChangeEvent<Change>) -> ChangeEvent<Change>? {
        switch event {
        case .willChange:
            return willChange()
        case .didNotChange:
            return didNotChange()
        case .didChange(let change):
            return didChange(change)
        }
    }

    mutating func willChange() -> ChangeEvent<Change>? {
        pendingCount += 1
        if pendingCount > 1 {
            return nil
        }
        return .willChange
    }

    mutating func didNotChange() -> ChangeEvent<Change>? {
        precondition(pendingCount > 0)
        pendingCount -= 1
        if pendingCount > 0 {
            return nil
        }
        if let change = pendingChange {
            return .didChange(change)
        }
        return .didNotChange
    }

    mutating func didChange(_ change: Change) -> ChangeEvent<Change>? {
        precondition(pendingCount > 0)
        pendingCount -= 1
        if pendingCount > 0 {
            pendingChange = pendingChange?.merged(with: change) ?? change
            return nil
        }
        guard let c = pendingChange else {
            return .didChange(change)
        }
        pendingChange = nil
        return .didChange(c.merged(with: change))
    }
}

internal enum FollowupEvent<Value> {
    case none
    case willChange
    case didNotChange
    case didChange(old: Value)

    func with(new: Value) -> ChangeEvent<SimpleChange<Value>>? {
        switch self {
        case .none:
            return nil
        case .willChange:
            return .willChange
        case .didNotChange:
            return .didNotChange
        case .didChange(let old):
            return .didChange(.init(from: old, to: new))
        }
    }
}

internal enum ObservableStateForTwoDependencies<Value> {
    case normal
    case firstPending(old: Value, changed: Bool)
    case secondPending(old: Value, changed: Bool)
    case bothPending(old: Value, changed: Bool)

    mutating func applyEventFromFirst<C: ChangeType>(_ value: Value, _ event: ChangeEvent<C>) -> FollowupEvent<Value> {
        switch event {
        case .willChange:
            switch self {
            case .normal:
                self = .firstPending(old: value, changed: false)
                return .willChange
            case .secondPending(let old, let changed):
                self = .bothPending(old: old, changed: changed)
                return .none
            default:
                preconditionFailure()
            }
        case .didNotChange:
            switch self {
            case .firstPending(let old, let changed):
                self = .normal
                return changed ? .didChange(old: old) : .didNotChange
            case .bothPending(let old, let changed):
                self = .secondPending(old: old, changed: changed)
                return .none
            default:
                preconditionFailure()
            }
        case .didChange(_):
            switch self {
            case .firstPending(let old, _):
                self = .normal
                return .didChange(old: old)
            case .bothPending(let old, _):
                self = .secondPending(old: old, changed: true)
                return .none
            default:
                preconditionFailure()
            }
        }
    }

    mutating func applyEventFromSecond<C: ChangeType>(_ value: Value, _ event: ChangeEvent<C>) -> FollowupEvent<Value> {
        switch event {
        case .willChange:
            switch self {
            case .normal:
                self = .secondPending(old: value, changed: false)
                return .willChange
            case .firstPending(let old, let changed):
                self = .bothPending(old: old, changed: changed)
                return .none
            default:
                preconditionFailure()
            }
        case .didNotChange:
            switch self {
            case .secondPending(let old, let changed):
                self = .normal
                return changed ? .didChange(old: old) : .didNotChange
            case .bothPending(let old, let changed):
                self = .firstPending(old: old, changed: changed)
                return .none
            default:
                preconditionFailure()
            }
        case .didChange(_):
            switch self {
            case .secondPending(let old, _):
                self = .normal
                return .didChange(old: old)
            case .bothPending(let old, _):
                self = .firstPending(old: old, changed: true)
                return .none
            default:
                preconditionFailure()
            }
        }
    }
}
