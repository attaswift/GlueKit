//
//  BatchedChanges.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-27.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableArrayType where Element: Hashable {
    public typealias ChangeBatch = (deleted: IndexSet, inserted: IndexSet, moved: [(from: Int, to: Int)])

    /// Return a source that describes changes in this array in terms of moved elements in addition to insertions and deletions.
    /// The reported changes can be directly fed as batch updates to a `UITableView` or a `UICollectionView`.
    public func batchedChanges() -> Source<ChangeBatch> {
        return MoveTrackingArray(inner: self).futureBatches
    }
}

extension ArrayChange where Element: Hashable {
    var insertedElements: [Element: Int] {
        var insertedElements: [Element: Int] = [:]
        for modification in modifications {
            switch modification {
            case .insert(let element, at: let index):
                insertedElements[element] = index
            case .removeElement(at: _):
                break
            case .replaceElement(at: let index, with: let element):
                insertedElements[element] = index
            case .replaceRange(let range, with: let elements):
                for i in 0 ..< elements.count {
                    insertedElements[elements[i]] = range.lowerBound + i
                }
            }
        }
        return insertedElements
    }
}

private class MoveTrackingArray<Element: Hashable>: SignalDelegate {
    public typealias ChangeBatch = ObservableArrayType.ChangeBatch

    private let inner: ObservableArray<Element>
    private var _futureBatches = OwningSignal<ChangeBatch, MoveTrackingArray>()

    private var connection: Connection? = nil
    private var value: [Element] = []

    init<Inner: ObservableArrayType>(inner: Inner) where Inner.Element == Element {
        self.inner = inner.observableArray
    }

    var futureBatches: Source<ChangeBatch> {
        return _futureBatches.with(self).source
    }

    func start(_ signal: Signal<ChangeBatch>) {
        precondition(connection == nil)
        value = inner.value
        connection = inner.futureChanges.connect { change in self.process(change) }
    }

    func stop(_ signal: Signal<ChangeBatch>) {
        precondition(connection != nil)
        connection?.disconnect()
        value = []
    }

    private func process(_ change: ArrayChange<Element>) {
        precondition(change.initialCount == value.count)

        let deletedIndices = change.deletedIndices
        var deletedElements: [Element: Int] = [:]
        for i in deletedIndices {
            deletedElements[value[i]] = i
        }

        var insertedElements = change.insertedElements

        var moves: [(from: Int, to: Int)] = []
        for (element, from) in deletedElements {
            if let to = insertedElements[element] {
                moves.append((from, to))
                deletedElements.removeValue(forKey: element)
                insertedElements.removeValue(forKey: element)
            }
        }

        value.apply(change)
        precondition(change.finalCount == value.count)

        let batch: ChangeBatch = (IndexSet(deletedElements.values), IndexSet(insertedElements.values), moves)

        self._futureBatches.send(batch)
    }
}
