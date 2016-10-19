//
//  ObservableValueType.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-04.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

public protocol ObservableType {
    associatedtype Change: ChangeType

    /// The current value of this observable.
    var value: Change.Value { get }

    /// A source that reports update transaction events for this observable.
    var updates: Source<Update<Change>> { get }
}

extension ObservableType {
    /// A source that reports changes to the value of this observable.
    /// Changes reported correspond to complete transactions in `self.updates`.
    public var changes: Source<Change> {
        return Source { sink in
            var merged: Change? = nil
            return self.updates.connect { event in
                switch event {
                case .beginTransaction:
                    assert(merged == nil)
                case .change(let change):
                    if merged == nil {
                        merged = change
                    }
                    else {
                        merged!.merge(with: change)
                    }
                case .endTransaction:
                    if let change = merged {
                        merged = nil
                        if !change.isEmpty {
                            sink.receive(change)
                        }
                    }
                }
            }
        }
    }
}

public protocol UpdatableType: ObservableType, SinkType {
    /// The current value of this observable.
    var value: Change.Value { get nonmutating set } // Nonmutating because UpdatableType needs to be a class if it holds the value directly.

    func withTransaction<Result>(_ body: () -> Result) -> Result
}

extension UpdatableType {
    public func receive(_ value: Change.Value) -> Void {
        self.value = value
    }
}
