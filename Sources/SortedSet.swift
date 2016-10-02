//
//  Sorting.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-15.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableSetType {
    public func sorted(by areInIncreasingOrder: @escaping (Element, Element) -> Bool) -> ObservableArray<Element> {
        return SortedObservableSet(input: self, sortedBy: areInIncreasingOrder).observableArray
    }

    public func sorted(by comparator: Observable<(Element, Element) -> Bool>) -> ObservableArray<Element> {
        let reference = ObservableArrayReference<Element>()

        let connection = comparator.values.connect { comparatorValue in
            reference.retarget(to: self.sorted(by: comparatorValue))
        }
        return reference.observableArray.holding(connection)
    }
}

class SortedObservableSet<S: ObservableSetType>: ObservableArrayType, SignalDelegate {
    typealias Base = [Element]
    typealias Element = S.Element
    typealias Change = ArrayChange<Element>

    private let input: S
    private let areInIncreasingOrder: (Element, Element) -> Bool

    internal private(set) var value: [Element] = []
    private var connection: Connection? = nil

    private var changeSignal = OwningSignal<Change>()

    internal var isBuffered: Bool { return true }
    internal var count: Int { return value.count }
    internal subscript(index: Int) -> Element { return value[index] }
    internal subscript(bounds: Range<Int>) -> ArraySlice<Element> { return value[bounds] }

    internal var changes: Source<ArrayChange<Element>> { return changeSignal.with(self).source }

    init(input: S, sortedBy areInIncreasingOrder: @escaping (Element, Element) -> Bool) {
        self.input = input
        self.areInIncreasingOrder = areInIncreasingOrder
        self.value = input.value.sorted(by: areInIncreasingOrder)
        self.connection = input.changes.connect { [weak self] change in
            self?.apply(change)
        }
    }

    private func apply(_ change: SetChange<Element>) {
        if change.isEmpty { return }
        var inserted = change.inserted.sorted(by: areInIncreasingOrder)
        var arrayChange = ArrayChange<Element>(initialCount: value.count)
        var nextValue: [Element] = []
        var i = 0
        var j = 0
        while i < value.count {
            let v = value[i]
            if change.removed.contains(v) {
                arrayChange.add(.remove(v, at: nextValue.count))
                i += 1
            }
            else if j < inserted.count {
                let nextOld = v
                let nextNew = inserted[j]
                if areInIncreasingOrder(nextOld, nextNew) {
                    nextValue.append(nextOld)
                    i += 1
                }
                else {
                    arrayChange.add(.insert(nextNew, at: nextValue.count))
                    nextValue.append(nextNew)
                    j += 1
                }
            }
            else {
                nextValue.append(v)
                i += 1
            }
        }
        if j < inserted.count {
            let remaining = Array(inserted.suffix(from: j))
            arrayChange.add(.replaceSlice([], at: nextValue.count, with: remaining))
            nextValue.append(contentsOf: remaining)
        }
        precondition(arrayChange.finalCount == nextValue.count)
        self.value = nextValue
        self.changeSignal.send(arrayChange)
    }

    func start(_ signal: Signal<Change>) {
        // We're always running
    }

    func stop(_ signal: Signal<Change>) {
        // We're always running
    }
}
