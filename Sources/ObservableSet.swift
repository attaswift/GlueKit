//
//  ObservableSet.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-12.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

/// This protocol defines an immutable set-like type, with only essential methods.
public protocol SetLikeCollection: Collection, Equatable {
    associatedtype Element

    func contains(_ member: Element) -> Bool
    func isSubset(of other: Self) -> Bool
    func isSuperset(of other: Self) -> Bool
}

extension Set: SetLikeCollection {}

public protocol ObservableSetType: ObservableCollection, SetLikeCollection {
    associatedtype Base: SetLikeCollection
    associatedtype Change = SetChange<Element>

    associatedtype Element: Hashable

    var futureChanges: Source<SetChange<Element>> { get }
    var observableSet: ObservableSet<Element> { get }
}

extension ObservableSetType where Element == Base.Element, IndexDistance == Base.IndexDistance {
    public var observableCount: Observable<IndexDistance> {
        let fv: (Void) -> Source<IndexDistance> = {
            var count = self.count
            return self.futureChanges.map { change in
                count += numericCast(change.inserted.count - change.removed.count)
                return count
            }
        }
        return Observable(
            getter: { self.count },
            futureValues: fv)
    }

    public func contains(_ member: Element) -> Bool { return value.contains(member) }
    public func isSubset(of other: Self) -> Bool { return value.isSubset(of: other.value) }
    public func isSuperset(of other: Self) -> Bool { return value.isSuperset(of: other.value) }

    public static func ==(a: Self, b: Self) -> Bool { return a.value == b.value }
}

extension ObservableSetType where Base == Set<Element>, Change == SetChange<Element> {
    public var observable: Observable<Base> {
        return Observable(
            getter: { return self.value },
            futureValues: {
                var value = self.value
                return self.futureChanges.map { (c: Change) -> Base in
                    value.apply(c)
                    return value
                }
        })
    }

    public var observableSet: ObservableSet<Element> {
        return ObservableSet(value: { self.value }, futureChanges: { self.futureChanges })
    }
}

public struct ObservableSet<Element: Hashable>: ObservableSetType {
    public typealias Base = Set<Element>
    public typealias Change = SetChange<Element>

    public typealias Index = Base.Index
    public typealias IndexDistance = Base.IndexDistance
    public typealias Indices = Base.Indices
    public typealias Iterator = Base.Iterator
    public typealias SubSequence = Base.SubSequence

    private let _value: () -> Set<Element>
    private let _futureChanges: () -> Source<Change>
    public init(value: @escaping () -> Set<Element>, futureChanges: @escaping () -> Source<Change>) {
        _value = value
        _futureChanges = futureChanges
    }

    public var value: Base { return _value() }
    public var futureChanges: Source<Change> { return _futureChanges() }

    public var observableSet: ObservableSet<Element> { return self }
}

extension ObservableSetType where Base == Set<Element> {
    public static func constant(_ value: Set<Element>) -> ObservableSet<Element> {
        return ObservableSet(value: { value }, futureChanges: { Source.empty() })
    }

    public static func emptyConstant() -> ObservableSet<Element> {
        return constant([])
    }
}
