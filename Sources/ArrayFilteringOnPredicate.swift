//
//  ArrayFilteringOnPredicate.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-09-26.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension ObservableArrayType {
    public func filter(_ isIncluded: @escaping (Element) -> Bool) -> AnyObservableArray<Element> {
        return ArrayFilteringOnPredicate<Self>(parent: self, isIncluded: isIncluded).anyObservableArray
    }
}

private final class ArrayFilteringOnPredicate<Parent: ObservableArrayType>: _BaseObservableArray<Parent.Element> {
    public typealias Element = Parent.Element
    public typealias Change = ArrayChange<Element>

    private struct ParentSink: UniqueOwnedSink {
        typealias Owner = ArrayFilteringOnPredicate
        
        unowned(unsafe) let owner: Owner
        
        func receive(_ update: ArrayUpdate<Parent.Element>) {
            owner.applyParentUpdate(update)
        }
    }
    
    private let parent: Parent
    private let isIncluded: (Element) -> Bool

    private var indexMapping: ArrayFilteringIndexmap<Element>

    init(parent: Parent, isIncluded: @escaping (Element) -> Bool) {
        self.parent = parent
        self.isIncluded = isIncluded
        self.indexMapping = ArrayFilteringIndexmap(initialValues: parent.value, isIncluded: isIncluded)
        super.init()
        parent.add(ParentSink(owner: self))
    }

    deinit {
        parent.remove(ParentSink(owner: self))
    }

    func applyParentUpdate(_ update: ArrayUpdate<Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            let filteredChange = self.indexMapping.apply(change)
            if !filteredChange.isEmpty {
                sendChange(filteredChange)
            }
        case .endTransaction:
            endTransaction()
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
}
