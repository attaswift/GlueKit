//
//  SetSortingByMappingToComparable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-15.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import BTree

extension ObservableSetType {
    /// Given a transformation into a comparable type, return an observable array containing transformed
    /// versions of elements in this set, in increasing order.
    public func sortedMap<Result: Comparable>(by transform: @escaping (Element) -> Result) -> AnyObservableArray<Result> {
        return SetSortingByMappingToComparable(parent: self, transform: transform).anyObservableArray
    }
}

extension ObservableSetType where Element: Comparable {
    /// Return an observable array containing the members of this set, in increasing order.
    public func sorted() -> AnyObservableArray<Element> {
        return self.sortedMap { $0 }
    }
}

private final class SetSortingByMappingToComparable<Parent: ObservableSetType, Element: Comparable>: _BaseObservableArray<Element> {
    typealias Change = ArrayChange<Element>

    private struct SortingSink: UniqueOwnedSink {
        typealias Owner = SetSortingByMappingToComparable
        
        unowned(unsafe) let owner: Owner
        
        func receive(_ update: SetUpdate<Parent.Element>) {
            owner.applyParentUpdate(update)
        }
    }
    
    private let parent: Parent
    private let transform: (Parent.Element) -> Element

    private var contents: Map<Element, Int> = [:]

    init(parent: Parent, transform: @escaping (Parent.Element) -> Element) {
        self.parent = parent
        self.transform = transform
        super.init()

        for element in parent.value {
            let transformed = transform(element)
            contents[transformed] = (contents[transformed] ?? 0) + 1
        }
        parent.add(SortingSink(owner: self))
    }

    deinit {
        parent.remove(SortingSink(owner: self))
    }

    func applyParentUpdate(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            var arrayChange = ArrayChange<Element>(initialCount: contents.count)
            for element in change.removed {
                let transformed = transform(element)
                guard let index = contents.index(forKey: transformed) else { fatalError("Removed element '\(transformed)' not found in sorted set") }
                let count = contents[index].1
                if count == 1 {
                    let offset = contents.offset(of: index)
                    let old = contents.remove(at: index)
                    if isConnected {
                        arrayChange.add(.remove(old.key, at: offset))
                    }
                }
                else {
                    contents[transformed] = count - 1
                }
            }
            for element in change.inserted {
                let transformed = transform(element)
                if let count = contents[transformed] {
                    precondition(count > 0)
                    contents[transformed] = count + 1
                }
                else {
                    contents[transformed] = 1
                    if isConnected {
                        let offset = contents.offset(of: transformed)!
                        arrayChange.add(.insert(transformed, at: offset))
                    }
                }
            }
            if isConnected, !arrayChange.isEmpty {
                sendChange(arrayChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }

    override var isBuffered: Bool { return false }
    override subscript(index: Int) -> Element { return contents.element(atOffset: index).0 }
    override subscript(bounds: Range<Int>) -> ArraySlice<Element> { return ArraySlice(contents.submap(withOffsets: bounds).lazy.map { $0.0 }) }
    override var value: Array<Element> { return Array(contents.lazy.map { $0.0 }) }
    override var count: Int { return contents.count }
}
