//
//  BatchedChanges.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-27.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableArrayType where Element: Hashable {
    public typealias ChangeBatch = (change: Change, deleted: IndexSet, inserted: IndexSet, moved: [(from: Int, to: Int)])

    /// Return a source that describes changes in this array in terms of moved elements in addition to insertions and deletions.
    /// The reported changes can be directly fed as batch updates to a `UITableView` or a `UICollectionView`.
    public func batched() -> BatchedArray<Element> {
        return BatchedArray(inner: self)
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

public class BatchedArray<Element: Hashable>: ObservableArrayType, SignalDelegate {
    public typealias Change = ArrayChange<Element>
    public typealias ChangeBatch = (change: Change, deleted: IndexSet, inserted: IndexSet, moved: [(from: Int, to: Int)])

    private let inner: ObservableArray<Element>
    private var _futureBatches = OwningSignal<ChangeBatch, BatchedArray>()

    private var connection: Connection? = nil
    private var _value: [Element] = []

    init<Inner: ObservableArrayType>(inner: Inner) where Inner.Element == Element {
        self.inner = inner.observableArray
    }

    private var isActive: Bool { return connection != nil }

    public var isBuffered: Bool { return true }

    public var count: Int { return isActive ? _value.count : inner.count }
    public var value: [Element] { return isActive ? _value : inner.value }

    public subscript(index: Int) -> Element { return isActive ? _value[index] : inner[index] }
    public subscript(bounds: Range<Int>) -> ArraySlice<Element> { return isActive ? _value[bounds] : inner[bounds] }

    public var futureChanges: Source<Change> { return _futureBatches.with(self).map { $0.change } }

    public var futureBatches: Source<ChangeBatch> {
        return _futureBatches.with(self).source
    }

    func start(_ signal: Signal<ChangeBatch>) {
        precondition(connection == nil)
        _value = inner.value
        connection = inner.futureChanges.connect { change in self.process(change) }
    }

    func stop(_ signal: Signal<ChangeBatch>) {
        precondition(connection != nil)
        connection?.disconnect()
        _value = []
    }

    private func process(_ change: ArrayChange<Element>) {
        precondition(change.initialCount == _value.count)


        var deletedElements: [Element: Int] = [:]
        var insertedElements: [Element: Int] = [:]
        var moves: [(from: Int, to: Int)] = []
        var delta = 0
        for modification in change.modifications {
            switch modification {
            case .insert(let element, at: let index):
                insertedElements[element] = index
            case .removeElement(at: let index):
                deletedElements[_value[index - delta]] = index - delta
            case .replaceElement(at: let index, with: let element):
                let old = _value[index - delta]
                deletedElements[old] = index - delta
                insertedElements[element] = index
            case .replaceRange(let range, with: let elements):
                for i in 0 ..< min(range.count, elements.count) {
                    let index = range.lowerBound + i
                    let old = _value[index - delta]
                    let new = elements[i]
                    deletedElements[old] = index - delta
                    insertedElements[new] = index
                }
                if range.count < elements.count {
                    for i in range.count ..< elements.count {
                        let new = elements[i]
                        let index = range.lowerBound + i
                        insertedElements[new] = index
                    }
                }
                else if range.count > elements.count {
                    for i in elements.count ..< range.count {
                        let index = range.lowerBound + i
                        let old = _value[index - delta]
                        deletedElements[old] = index - delta
                    }
                }
            }
            delta += modification.deltaCount
        }

        for (element, from) in deletedElements {
            if let to = insertedElements[element] {
                moves.append((from, to))
                deletedElements.removeValue(forKey: element)
                insertedElements.removeValue(forKey: element)
            }
        }

        _value.apply(change)
        precondition(change.finalCount == _value.count)

        let batch: ChangeBatch = (change: change,
                                  deleted: IndexSet(deletedElements.values),
                                  inserted: IndexSet(insertedElements.values),
                                  moved: moves)
        self._futureBatches.send(batch)
    }
}
