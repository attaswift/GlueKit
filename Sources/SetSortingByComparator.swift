//
//  SetSortingByComparator.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableSetType where Change == SetChange<Element> {
    public func sorted(by areInIncreasingOrder: @escaping (Element, Element) -> Bool) -> AnyObservableArray<Element> {
        let comparator = Comparator(areInIncreasingOrder)
        return self
            .sorted(by: { [unowned comparator] in ComparableWrapper($0, comparator) })
            .map { [comparator] in _ = comparator; return $0.element }
    }

    public func sorted<Comparator: ObservableValueType>(by comparator: Comparator) -> AnyObservableArray<Element>
    where Comparator.Value == (Element, Element) -> Bool, Comparator.Change == ValueChange<Comparator.Value> {
        let reference: AnyObservableValue<AnyObservableArray<Element>> = comparator.map { comparator in
            self.sorted(by: comparator).anyObservableArray
        }
        return reference.unpacked()
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
