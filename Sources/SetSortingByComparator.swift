//
//  SetSortingByComparator.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableSetType {
    public func sorted(by areInIncreasingOrder: @escaping (Element, Element) -> Bool) -> AnyObservableArray<Element> {
        let comparator = Comparator(areInIncreasingOrder)
        return self
            .sorted(by: { [unowned(unsafe) comparator] in ComparableWrapper($0, comparator) })
            .map { [comparator] in _ = comparator; return $0.element }
    }

    public func sorted<Comparator: ObservableValueType>(by comparator: Comparator) -> AnyObservableArray<Element> where Comparator.Value == (Element, Element) -> Bool, Comparator.Change == ValueChange<Comparator.Value> {
        let reference = ObservableArrayReference<Element>()
        let connection = comparator.values.connect { comparatorValue in
            reference.retarget(to: self.sorted(by: comparatorValue))
        }
        return reference.observableArray.holding(connection)
    }
}

private final class Comparator<Element: Equatable> {
    let comparator: (Element, Element) -> Bool

    init(_ comparator: @escaping (Element, Element) -> Bool) {
        self.comparator = comparator
    }
    func compare(_ a: Element, _ b: Element) -> Bool {
        return comparator(a, b)
    }
}

private struct ComparableWrapper<Element: Equatable>: Comparable {
    unowned(unsafe) let comparator: Comparator<Element>
    let element: Element

    init(_ element: Element, _ comparator: Comparator<Element>) {
        self.comparator = comparator
        self.element = element
    }
    static func ==(a: ComparableWrapper<Element>, b: ComparableWrapper<Element>) -> Bool {
        return a.element == b.element
    }
    static func <(a: ComparableWrapper<Element>, b: ComparableWrapper<Element>) -> Bool {
        return a.comparator.compare(a.element, b.element)
    }
}
