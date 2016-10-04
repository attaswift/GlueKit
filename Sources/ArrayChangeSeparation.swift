//
//  ArrayChangeSeparation.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-27.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

private func separationError() -> Never {
    fatalError("Changes in arrays with duplicate elements cannot be separated")
}

extension ArrayChange where Element: Hashable {
    /// Separates this change into components that can be directly fed into a `UITableView` or a `UICollectionView` as a batch update.
    /// 
    /// - Requires: The array must not contain duplicate elements.
    func separated() -> SeparatedArrayChange<Element> {
        return SeparatedArrayChange(self)
    }
}

public struct SeparatedArrayChange<Element: Hashable> {
    // The original change.
    public var change: ArrayChange<Element>

    /// The indices that are to be deleted.
    public var deleted = IndexSet()
    /// The indices that are inserted.
    public var inserted = IndexSet()
    /// The old and new indices of elements that are to be moved.
    /// (This includes elements that need to be refreshed.)
    public var moved: [(from: Int, to: Int)] = []

    init(_ change: ArrayChange<Element>) {
        self.change = change

        var deletedElements: [Element: Int] = [:]
        var insertedElements: [Element: Int] = [:]
        var delta = 0

        for modification in change.modifications {
            switch modification {
            case .insert(let new, at: let index):
                guard insertedElements.updateValue(index, forKey: new) == nil else { separationError() }
            case .remove(let old, at: let index):
                guard deletedElements.updateValue(index - delta, forKey: old) == nil else { separationError() }
            case .replace(let old, at: let index, with: let new):
                guard deletedElements.updateValue(index - delta, forKey: old) == nil else { separationError() }
                guard insertedElements.updateValue(index, forKey: new) == nil else { separationError() }
            case .replaceSlice(let old, at: let index, with: let new):
                for i in 0 ..< min(old.count, new.count) {
                    guard deletedElements.updateValue(index + i - delta, forKey: old[i]) == nil else { separationError() }
                    guard insertedElements.updateValue(index + i, forKey: new[i]) == nil else { separationError() }
                }

                if old.count < new.count {
                    for i in old.count ..< new.count {
                        guard insertedElements.updateValue(index + i, forKey: new[i]) == nil else { separationError() }
                    }
                }
                else if old.count > new.count {
                    for i in new.count ..< old.count {
                        guard deletedElements.updateValue(index + i - delta, forKey: old[i]) == nil else { separationError() }
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
