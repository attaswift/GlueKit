//
//  ArrayFilteringIndexmap.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import BTree

internal struct ArrayFilteringIndexmap<Element> {
    let isIncluded: (Element) -> Bool
    var matchingIndices = SortedSet<Int>()

    init(initialValues values: [Element], isIncluded: @escaping (Element) -> Bool) {
        self.isIncluded = isIncluded
        for index in values.indices {
            if isIncluded(values[index]) {
                matchingIndices.insert(index)
            }
        }
    }

    mutating func apply(_ change: ArrayChange<Element>) -> ArrayChange<Element> {
        var filteredChange = ArrayChange<Element>(initialCount: matchingIndices.count)
        for mod in change.modifications {
            switch mod {
            case .insert(let element, at: let index):
                matchingIndices.shift(startingAt: index, by: 1)
                if isIncluded(element) {
                    matchingIndices.insert(index)
                    filteredChange.add(.insert(element, at: matchingIndices.offset(of: index)!))
                }
            case .remove(let element, at: let index):
                if let filteredIndex = matchingIndices.offset(of: index) {
                    filteredChange.add(.remove(element, at: filteredIndex))
                }
                matchingIndices.shift(startingAt: index + 1, by: -1)
            case .replace(let old, at: let index, with: let new):
                switch (matchingIndices.offset(of: index), isIncluded(new)) {
                case (.some(let offset), true):
                    filteredChange.add(.replace(old, at: offset, with: new))
                case (.none, true):
                    matchingIndices.insert(index)
                    filteredChange.add(.insert(new, at: matchingIndices.offset(of: index)!))
                case (.some(let offset), false):
                    matchingIndices.remove(index)
                    filteredChange.add(.remove(old, at: offset))
                case (.none, false):
                    // Do nothing
                    break
                }
            case .replaceSlice(let old, at: let index, with: let new):
                let filteredIndex = matchingIndices.prefix(upTo: index).count
                let filteredOld = matchingIndices.intersection(elementsIn: index ..< index + old.count).map { old[$0 - index] }
                var filteredNew: [Element] = []

                matchingIndices.subtract(elementsIn: index ..< index + old.count)
                matchingIndices.shift(startingAt: index + old.count, by: new.count - old.count)
                for i in 0 ..< new.count {
                    if isIncluded(new[i]) {
                        matchingIndices.insert(index + i)
                        filteredNew.append(new[i])
                    }
                }
                if let mod = ArrayModification(replacing: filteredOld, at: filteredIndex, with: filteredNew) {
                    filteredChange.add(mod)
                }
            }
        }
        return filteredChange
    }

    mutating func insert(_ index: Int) -> Int? {
        guard !matchingIndices.contains(index) else { return nil }
        matchingIndices.insert(index)
        return matchingIndices.offset(of: index)!
    }

    mutating func remove(_ index: Int) -> Int? {
        guard let filteredIndex = matchingIndices.offset(of: index) else { return nil }
        matchingIndices.remove(index)
        return filteredIndex
    }
}
