//
//  ArrayFiltering.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-09-26.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import BTree

private struct IndexMapping<Element> {
    let test: (Element) -> Bool
    var matchingIndices = SortedSet<Int>()

    init(initialValues values: [Element], test: @escaping (Element) -> Bool) {
        self.test = test
        for index in values.indices {
            if test(values[index]) {
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
                if test(element) {
                    matchingIndices.insert(index)
                    filteredChange.add(.insert(element, at: matchingIndices.offset(of: index)!))
                }
            case .remove(let element, at: let index):
                if let filteredIndex = matchingIndices.offset(of: index) {
                    filteredChange.add(.remove(element, at: filteredIndex))
                }
                matchingIndices.shift(startingAt: index + 1, by: -1)
            case .replace(let old, at: let index, with: let new):
                switch (matchingIndices.offset(of: index), test(new)) {
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
                    if test(new[i]) {
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

extension ObservableArrayType {
    public func filter(test: @escaping (Element) -> Bool) -> ObservableArray<Element> {
        return ArrayFilteringOnPredicate<Self>(parent: self, test: test).observableArray
    }
}

private final class ArrayFilteringOnPredicate<Parent: ObservableArrayType>: ObservableArrayBase<Parent.Element> {
    public typealias Element = Parent.Element
    public typealias Change = ArrayChange<Element>

    private let parent: Parent
    private let test: (Element) -> Bool

    private var indexMapping: IndexMapping<Element>
    private var changeSignal = OwningSignal<Change>()
    private var connection: Connection? = nil

    init(parent: Parent, test: @escaping (Element) -> Bool) {
        self.parent = parent
        self.test = test
        self.indexMapping = IndexMapping(initialValues: parent.value, test: test)
        super.init()
        connection = parent.changes.connect { [unowned self] change in self.apply(change) }
    }

    deinit {
        connection!.disconnect()
    }

    private func apply(_ change: ArrayChange<Element>) {
        let filteredChange = self.indexMapping.apply(change)
        if !filteredChange.isEmpty {
            self.changeSignal.send(filteredChange)
        }
    }

    override var isBuffered: Bool {
        return false
    }

    override subscript(index: Int) -> Element {
        return parent[indexMapping.matchingIndices[index]]
    }

    override subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        precondition(0 <= bounds.lowerBound && bounds.lowerBound <= bounds.upperBound && bounds.upperBound <= count)
        var result: [Element] = []
        result.reserveCapacity(bounds.count)
        for index in indexMapping.matchingIndices[bounds] {
            result.append(parent[index])
        }
        return ArraySlice(result)
    }

    override var value: Array<Element> {
        return indexMapping.matchingIndices.map { parent[$0] }
    }

    override var count: Int {
        return indexMapping.matchingIndices.count
    }

    override var changes: Source<ArrayChange<Base.Element>> {
        return changeSignal.with(retained: self).source
    }
}

extension ObservableArrayType {
    public func filter<Test: ObservableValueType>(test: @escaping (Element) -> Test) -> ObservableArray<Element> where Test.Value == Bool {
        return ArrayFilteringOnObservableBool<Self, Test>(parent: self, test: test).observableArray
    }
}

private class ArrayFilteringOnObservableBool<Parent: ObservableArrayType, Test: ObservableValueType>: ObservableArrayBase<Parent.Element> where Test.Value == Bool {
    public typealias Element = Parent.Element
    public typealias Change = ArrayChange<Element>

    private let parent: Parent
    private let test: (Element) -> Test

    private var indexMapping: IndexMapping<Element>
    private var changeSignal = OwningSignal<Change>()
    private var baseConnection: Connection? = nil
    private var elementConnections = RefList<Connection>()

    init(parent: Parent, test: @escaping (Element) -> Test) {
        self.parent = parent
        self.test = test
        let elements = parent.value
        self.indexMapping = IndexMapping(initialValues: elements, test: { test($0).value })
        super.init()
        self.baseConnection = parent.changes.connect { [unowned self] change in self.apply(change) }
        self.elementConnections = RefList(elements.lazy.map { [unowned self] element in self.connect(to: element) })
    }

    deinit {
        self.baseConnection!.disconnect()
        self.elementConnections.forEach { $0.disconnect() }
    }

    private func apply(_ change: ArrayChange<Element>) {
        for mod in change.modifications {
            let inputRange = mod.inputRange
            inputRange.forEach { elementConnections[$0].disconnect() }
            elementConnections.replaceSubrange(inputRange, with: mod.newElements.map { self.connect(to: $0) })
        }
        let filteredChange = self.indexMapping.apply(change)
        if !filteredChange.isEmpty {
            self.changeSignal.send(filteredChange)
        }
    }

    private func connect(to element: Element) -> Connection {
        var connection: Connection! = nil
        connection = test(element).changes.connect { [unowned self] change in self.apply(change, from: connection) }
        return connection
    }

    private func apply(_ change: SimpleChange<Bool>, from connection: Connection) {
        if change.old == change.new { return }
        let index = elementConnections.index(of: connection)!
        let c = indexMapping.matchingIndices.count
        if change.new, let filteredIndex = indexMapping.insert(index) {
            self.changeSignal.send(ArrayChange(initialCount: c, modification: .insert(parent[index], at: filteredIndex)))
        }
        else if !change.new, let filteredIndex = indexMapping.remove(index) {
            self.changeSignal.send(ArrayChange(initialCount: c, modification: .remove(parent[index], at: filteredIndex)))
        }
    }

    override var isBuffered: Bool { return false }

    override subscript(index: Int) -> Element {
        return parent[indexMapping.matchingIndices[index]]
    }

    override subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        precondition(0 <= bounds.lowerBound && bounds.lowerBound <= bounds.upperBound && bounds.upperBound <= count)
        var result: [Element] = []
        result.reserveCapacity(bounds.count)
        for index in indexMapping.matchingIndices[bounds] {
            result.append(parent[index])
        }
        return ArraySlice(result)
    }

    override var value: Array<Element> {
        return indexMapping.matchingIndices.map { parent[$0] }
    }

    override var count: Int {
        return indexMapping.matchingIndices.count
    }

    override var changes: Source<ArrayChange<Base.Element>> {
        return changeSignal.with(retained: self).source
    }
}
