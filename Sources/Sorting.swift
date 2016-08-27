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
}

class SortedObservableSet<S: ObservableSetType>: ObservableArrayType, SignalDelegate {
    typealias Base = [Element]
    typealias Element = S.Element
    typealias Change = ArrayChange<Element>

    private let input: S
    private let areInIncreasingOrder: (Element, Element) -> Bool

    internal private(set) var value: [Element] = []
    private var connection: Connection? = nil

    private var changeSignal = OwningSignal<Change, SortedObservableSet>()

    internal var isBuffered: Bool { return true }
    internal var count: Int { return value.count }
    internal subscript(index: Int) -> Element { return value[index] }
    internal subscript(bounds: Range<Int>) -> ArraySlice<Element> { return value[bounds] }

    internal var futureChanges: Source<ArrayChange<Element>> { return changeSignal.with(self).source }

    init(input: S, sortedBy areInIncreasingOrder: @escaping (Element, Element) -> Bool) {
        self.input = input
        self.areInIncreasingOrder = areInIncreasingOrder
        self.value = input.value.sorted(by: areInIncreasingOrder)
        self.connection = input.futureChanges.connect { [weak self] change in
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
            if change.removed.contains(value[i]) {
                arrayChange.addModification(.removeElement(at: nextValue.count))
                i += 1
            }
            else if j < inserted.count {
                let nextOld = value[i]
                let nextNew = inserted[j]
                if areInIncreasingOrder(nextOld, nextNew) {
                    nextValue.append(nextOld)
                    i += 1
                }
                else {
                    arrayChange.addModification(.insert(nextNew, at: nextValue.count))
                    nextValue.append(nextNew)
                    j += 1
                }
            }
            else {
                nextValue.append(value[i])
                i += 1
            }
        }
        if j < inserted.count {
            let remaining = Array(inserted.suffix(from: j))
            arrayChange.addModification(.replaceRange(nextValue.count ..< nextValue.count, with: remaining))
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
