//
//  SetSortingByMappingToComparable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-15.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import BTree

extension ObservableSetType {
    /// Given a transformation into a comparable type, return an observable array containing transformed
    /// versions of elements in this set, in increasing order.
    public func sorted<Result: Comparable>(by transform: @escaping (Element) -> Result) -> AnyObservableArray<Result> {
        return SetSortingByMappingToComparable(parent: self, transform: transform).observableArray
    }
}

extension ObservableSetType where Element: Comparable {
    /// Return an observable array containing the members of this set, in increasing order.
    public func sorted() -> AnyObservableArray<Element> {
        return self.sorted { $0 }
    }
}

private final class SetSortingByMappingToComparable<Parent: ObservableSetType, Element: Comparable>: _AbstractObservableArray<Element> {
    typealias Change = ArrayChange<Element>

    private let parent: Parent
    private let transform: (Parent.Element) -> Element

    private var contents: Map<Element, Int> = [:]
    private var state = TransactionState<Change>()
    private var baseConnection: Connection? = nil

    init(parent: Parent, transform: @escaping (Parent.Element) -> Element) {
        self.parent = parent
        self.transform = transform
        super.init()

        for element in parent.value {
            let transformed = transform(element)
            contents[transformed] = (contents[transformed] ?? 0) + 1
        }
        baseConnection = parent.updates.connect { [unowned self] in self.apply($0) }
    }

    deinit {
        baseConnection?.disconnect()
    }

    private func apply(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            state.begin()
        case .change(let change):
            var arrayChange = ArrayChange<Element>(initialCount: contents.count)
            for element in change.removed {
                let transformed = transform(element)
                guard let index = contents.index(forKey: transformed) else { fatalError("Removed element '\(transformed)' not found in sorted set") }
                let count = contents[index].1
                if count == 1 {
                    let offset = contents.offset(of: index)
                    let old = contents.remove(at: index)
                    if state.isConnected {
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
                    contents[transformed] = count + 1
                }
                else {
                    contents[transformed] = 1
                    if state.isConnected {
                        let offset = contents.offset(of: transformed)!
                        arrayChange.add(.insert(transformed, at: offset))
                    }
                }
            }
            if state.isConnected, !arrayChange.isEmpty {
                state.send(arrayChange)
            }
        case .endTransaction:
            state.end()
        }
    }

    override var isBuffered: Bool { return false }
    override subscript(index: Int) -> Element { return contents.element(atOffset: index).0 }
    override subscript(bounds: Range<Int>) -> ArraySlice<Element> { return ArraySlice(contents.submap(withOffsets: bounds).lazy.map { $0.0 }) }
    override var value: Array<Element> { return Array(contents.lazy.map { $0.0 }) }
    override var count: Int { return contents.count }
    override var updates: ArrayUpdateSource<Element> { return state.source(retaining: self) }
}
