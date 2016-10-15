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

    /// A source that reports changes to the value of this observable.
    var changeEvents: Source<ChangeEvent<Change>> { get }
}

extension ObservableType {
    public var changes: Source<Change> {
        return changeEvents.flatMap { $0.change }
    }
}

public protocol UpdatableType: ObservableType, SinkType {
    /// The current value of this observable.
    var value: Change.Value { get nonmutating set } // Nonmutating because UpdatableType needs to be a class if it holds the value directly.
}

extension UpdatableType {
    public func receive(_ value: Change.Value) -> Void {
        self.value = value
    }
}
