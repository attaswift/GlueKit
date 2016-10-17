//
//  DistinctValue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

public extension ObservableValueType where Change == ValueChange<Value> {
    public func distinct(_ equalityTest: @escaping (Value, Value) -> Bool) -> Observable<Value> {
        let buffered = self.buffered()
        return Observable(
            getter: { buffered.value },
            updates: { buffered.updates.flatMap { update in update.filter { !equalityTest($0.old, $0.new) } } })
    }
}

public extension ObservableValueType where Change == ValueChange<Value>, Value: Equatable {
    public func distinct() -> Observable<Value> {
        return distinct(==)
    }
}

public extension UpdatableValueType where Change == ValueChange<Value> {
    public func distinct(_ equalityTest: @escaping (Value, Value) -> Bool) -> Updatable<Value> {
        let buffered = self.buffered()
        return Updatable(
            getter: { buffered.value },
            updater: self.update,
            updates: { buffered.updates.flatMap { update in update.filter { !equalityTest($0.old, $0.new) } } })
    }
}

public extension UpdatableValueType where Change == ValueChange<Value>, Value: Equatable {
    public func distinct() -> Updatable<Value> {
        return distinct(==)
    }
}
