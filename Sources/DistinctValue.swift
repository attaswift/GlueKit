//
//  DistinctValue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

public extension ObservableValueType {
    public func distinct(_ equalityTest: @escaping (Value, Value) -> Bool) -> Observable<Value> {
        return Observable(
            getter: { self.value },
            changeEvents: { self.changeEvents.map { event in event.filter { !equalityTest($0.old, $0.new) } } })
    }
}

public extension ObservableValueType where Value: Equatable {
    public func distinct() -> Observable<Value> {
        return distinct(==)
    }
}

public extension UpdatableValueType {
    public func distinct(_ equalityTest: @escaping (Value, Value) -> Bool) -> Updatable<Value> {
        return Updatable(
            getter: self.get,
            updater: self.update,
            changeEvents: { self.changeEvents.map { event in event.filter { !equalityTest($0.old, $0.new) } } })
    }
}

public extension UpdatableValueType where Value: Equatable {
    public func distinct() -> Updatable<Value> {
        return distinct(==)
    }
}
