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
    var changes: Source<Change> { get }
}
