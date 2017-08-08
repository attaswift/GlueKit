//
//  ArrayFilteringOnObservableBool.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension ObservableArrayType {
    public func filter<Test: ObservableValueType>(_ isIncluded: @escaping (Element) -> Test) -> AnyObservableArray<Element>
    where Test.Value == Bool {
        return ArrayFilteringOnObservableBool<Self, Test>(parent: self, isIncluded: isIncluded).anyObservableArray
    }

    public func filter<Predicate: ObservableValueType>(_ isIncluded: Predicate) -> AnyObservableArray<Element>
    where Predicate.Value == (Element) -> Bool {
        return self.filter(isIncluded.map { predicate -> Optional<(Element) -> Bool> in predicate })
    }

    public func filter<Predicate: ObservableValueType>(_ isIncluded: Predicate) -> AnyObservableArray<Element>
    where Predicate.Value == Optional<(Element) -> Bool> {
        let reference: AnyObservableValue<AnyObservableArray<Element>> = isIncluded.map { predicate in
            if let predicate: (Element) -> Bool = predicate {
                return self.filter(predicate).anyObservableArray
            }
            else {
                return self.anyObservableArray
            }
        }
        return reference.unpacked()
    }
}

private class ArrayFilteringOnObservableBool<Parent: ObservableArrayType, Test: ObservableValueType>: _BaseObservableArray<Parent.Element>
where Test.Value == Bool {
    typealias Element = Parent.Element
    typealias Change = ArrayChange<Element>

    private struct ParentSink: UniqueOwnedSink {
        typealias Owner = ArrayFilteringOnObservableBool
        
        unowned(unsafe) let owner: Owner
        
        func receive(_ update: ArrayUpdate<Parent.Element>) {
            owner.applyParentUpdate(update)
        }
    }
    
    private final class FieldSink: SinkType, RefListElement {
        typealias Owner = ArrayFilteringOnObservableBool
        
        unowned let owner: Owner
        let field: Test
        var refListLink = RefListLink<FieldSink>()
        
        init(owner: Owner, field: Test) {
            self.owner = owner
            self.field = field
            
            field.add(self)
        }
        
        func disconnect() {
            field.remove(self)
        }
        
        func receive(_ update: ValueUpdate<Bool>) {
            owner.applyFieldUpdate(update, from: self)
        }
    }

    private let parent: Parent
    private let isIncluded: (Element) -> Test

    private var indexMapping: ArrayFilteringIndexmap<Element>
    private var elementConnections = RefList<FieldSink>()

    init(parent: Parent, isIncluded: @escaping (Element) -> Test) {
        self.parent = parent
        self.isIncluded = isIncluded
        let elements = parent.value
        self.indexMapping = ArrayFilteringIndexmap(initialValues: elements, isIncluded: { isIncluded($0).value })
        super.init()
        parent.updates.add(ParentSink(owner: self))
        self.elementConnections = RefList(elements.lazy.map { FieldSink(owner: self, field: isIncluded($0)) })
    }

    deinit {
        parent.updates.remove(ParentSink(owner: self))
        self.elementConnections.forEach { $0.disconnect() }
    }

    private func applyParentUpdate(_ update: ArrayUpdate<Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            for mod in change.modifications {
                let inputRange = mod.inputRange
                inputRange.forEach { elementConnections[$0].disconnect() }
                elementConnections.replaceSubrange(inputRange, with: mod.newElements.map { FieldSink(owner: self, field: isIncluded($0)) })
            }
            let filteredChange = self.indexMapping.apply(change)
            if !filteredChange.isEmpty {
                sendChange(filteredChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }

    private func applyFieldUpdate(_ update: ValueUpdate<Bool>, from sink: FieldSink) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            if change.old == change.new { return }
            let index = elementConnections.index(of: sink)!
            let c = indexMapping.matchingIndices.count
            if change.new, let filteredIndex = indexMapping.insert(index) {
                sendChange(ArrayChange(initialCount: c, modification: .insert(parent[index], at: filteredIndex)))
            }
            else if !change.new, let filteredIndex = indexMapping.remove(index) {
                sendChange(ArrayChange(initialCount: c, modification: .remove(parent[index], at: filteredIndex)))
            }
        case .endTransaction:
            endTransaction()
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
}
