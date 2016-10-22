//
//  ObservableValueType.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-04.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

public protocol ObservableType {
    associatedtype Change: ChangeType

    /// The current value of this observable.
    var value: Change.Value { get }

    /// A source that reports update transaction events for this observable.
    var updates: AnySource<Update<Change>> { get }
}

public protocol UpdatableType: ObservableType, SinkType {
    /// The current value of this observable.
    ///
    /// The setter is nonmutating because the value ultimately needs to be stored in a reference type anyway.
    var value: Change.Value { get nonmutating set }

    func withTransaction<Result>(_ body: () -> Result) -> Result
}

extension UpdatableType {
    public func receive(_ value: Change.Value) -> Void {
        self.value = value
    }

}
