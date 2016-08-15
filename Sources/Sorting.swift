//
//  Sorting.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-15.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableSetType where Base == Set<Element>, Element == Iterator.Element {
    public func sorted(by areInIncreasingOrder: @escaping (Iterator.Element, Iterator.Element) -> Bool) -> ObservableArray<Element> {
        return SortedObservableSet(source: self, sortedBy: areInIncreasingOrder).observableArray
    }
}

class SortedObservableSet<S: ObservableSetType>: ObservableArrayType where S.Base == Set<S.Element> {
    typealias Base = [Element]
    typealias Element = S.Element

    typealias Iterator = Base.Iterator
    typealias Index = Int
    typealias IndexDistance = Int
    typealias Indices = Base.Indices
    typealias SubSequence = Base.SubSequence

    private let source: S
    private let areInIncreasingOrder: (Element, Element) -> Bool

    internal private(set) var value: [Element] = []
    private var connection: Connection? = nil

    private let changeSignal = Signal<ArrayChange<Element>>()

    internal var count: Int { return value.count }
    internal func lookup(_ range: Range<Int>) -> SubSequence { return value[range] }
    internal var futureChanges: Source<ArrayChange<Element>> { return changeSignal.source }

    internal var observableArray: ObservableArray<Element> {
        return ObservableArray(
            count: { self.value.count },
            lookup: { self.value[$0] },
            futureChanges: { self.changeSignal.source }
        )
    }

    init(source: S, sortedBy areInIncreasingOrder: @escaping (Element, Element) -> Bool) {
        self.source = source
        self.areInIncreasingOrder = areInIncreasingOrder
        self.value = source.value.sorted(by: areInIncreasingOrder)
        self.connection = source.futureChanges.connect { [weak self] change in
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
                arrayChange.addModification(.removeAt(nextValue.count))
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
            arrayChange.addModification(.replaceRange(nextValue.count ..< nextValue.count, with: inserted))
            nextValue.append(contentsOf: inserted.suffix(from: j))
        }
        self.value = nextValue
        self.changeSignal.send(arrayChange)
    }
}
