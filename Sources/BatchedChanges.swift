//
//  BatchedChanges.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-27.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

private func batchError() -> Never {
    fatalError("Changes in arrays with duplicate elements cannot be batched")
}

public struct BatchedArrayChange<Element: Hashable> {
    public var change: ArrayChange<Element>
    public var deleted = IndexSet()
    public var inserted = IndexSet()
    public var moved: [(from: Int, to: Int)] = []

    init(_ change: ArrayChange<Element>) {
        self.change = change

        var deletedElements: [Element: Int] = [:]
        var insertedElements: [Element: Int] = [:]
        var delta = 0

        for modification in change.modifications {
            switch modification {
            case .insert(let new, at: let index):
                guard insertedElements.updateValue(index, forKey: new) == nil else { batchError() }
            case .remove(let old, at: let index):
                guard deletedElements.updateValue(index - delta, forKey: old) == nil else { batchError() }
            case .replace(let old, at: let index, with: let new):
                guard deletedElements.updateValue(index - delta, forKey: old) == nil else { batchError() }
                guard insertedElements.updateValue(index, forKey: new) == nil else { batchError() }
            case .replaceSlice(let old, at: let index, with: let new):
                for i in 0 ..< min(old.count, new.count) {
                    guard deletedElements.updateValue(index + i - delta, forKey: old[i]) == nil else { batchError() }
                    guard insertedElements.updateValue(index + i, forKey: new[i]) == nil else { batchError() }
                }

                if old.count < new.count {
                    for i in old.count ..< new.count {
                        guard insertedElements.updateValue(index + i, forKey: new[i]) == nil else { batchError() }
                    }
                }
                else if old.count > new.count {
                    for i in new.count ..< old.count {
                        guard deletedElements.updateValue(index + i - delta, forKey: old[i]) == nil else { batchError() }
                    }
                }
            }
            delta += modification.deltaCount
        }

        for (element, from) in deletedElements {
            if let to = insertedElements[element] {
                moved.append((from, to))
                deletedElements.removeValue(forKey: element)
                insertedElements.removeValue(forKey: element)
            }
        }

        self.deleted = IndexSet(deletedElements.values)
        self.inserted = IndexSet(insertedElements.values)
    }
}

extension ObservableArrayType where Element: Hashable {
    /// Return a source that describes changes in this array in terms of moved elements in addition to insertions and deletions.
    /// The reported changes can be directly fed as batch updates to a `UITableView` or a `UICollectionView`.
    public var batchedChanges: Source<BatchedArrayChange<Element>> {
        return changes.map { BatchedArrayChange($0) }
    }
}
