//
//  ArrayFilteringOnPredicate.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-09-26.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableArrayType {
    public func filter(test: @escaping (Element) -> Bool) -> ObservableArray<Element> {
        return ArrayFilteringOnPredicate<Self>(parent: self, test: test).observableArray
    }
}

private final class ArrayFilteringOnPredicate<Parent: ObservableArrayType>: _ObservableArrayBase<Parent.Element> {
    public typealias Element = Parent.Element
    public typealias Change = ArrayChange<Element>

    private let parent: Parent
    private let test: (Element) -> Bool

    private var indexMapping: ArrayFilteringIndexmap<Element>
    private var state = TransactionState<Change>()
    private var connection: Connection? = nil

    init(parent: Parent, test: @escaping (Element) -> Bool) {
        self.parent = parent
        self.test = test
        self.indexMapping = ArrayFilteringIndexmap(initialValues: parent.value, test: test)
        super.init()
        connection = parent.updates.connect { [unowned self] in self.apply($0) }
    }

    deinit {
        connection!.disconnect()
    }

    private func apply(_ update: ArrayUpdate<Element>) {
        switch update {
        case .beginTransaction:
            state.begin()
        case .change(let change):
            let filteredChange = self.indexMapping.apply(change)
            if !filteredChange.isEmpty {
                self.state.send(filteredChange)
            }
        case .endTransaction:
            state.end()
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

    override var updates: ArrayUpdateSource<Base.Element> {
        return state.source(retaining: self)
    }
}
