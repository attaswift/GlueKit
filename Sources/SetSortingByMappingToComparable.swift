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
    public func sorted<Result: Comparable>(by transform: @escaping (Element) -> Result) -> ObservableArray<Result> {
        return SetSortingByMappingToComparable(base: self, transform: transform).observableArray
    }
}

extension ObservableSetType where Element: Comparable {
    /// Return an observable array containing the members of this set, in increasing order.
    public func sorted() -> ObservableArray<Element> {
        return self.sorted { $0 }
    }
}

private final class SetSortingByMappingToComparable<S: ObservableSetType, R: Comparable>: ObservableArrayBase<R> {
    typealias Element = R
    typealias Change = ArrayChange<R>

    private let base: S
    private let transform: (S.Element) -> R

    private var state: Map<R, Int> = [:]
    private var signal = OwningSignal<Change>()
    private var baseConnection: Connection? = nil

    init(base: S, transform: @escaping (S.Element) -> R) {
        self.base = base
        self.transform = transform
        super.init()

        for element in base.value {
            let transformed = transform(element)
            state[transformed] = (state[transformed] ?? 0) + 1
        }
        baseConnection = base.changes.connect { [unowned self] change in self.apply(change) }
    }

    deinit {
        baseConnection?.disconnect()
    }

    private func apply(_ change: SetChange<S.Element>) {
        var arrayChange: ArrayChange<Element>? = signal.isConnected ? ArrayChange(initialCount: state.count) : nil
        for element in change.removed {
            let transformed = transform(element)
            guard let index = state.index(forKey: transformed) else { fatalError("Removed element '\(transformed)' not found in sorted set") }
            let count = state[index].1
            if count == 1 {
                let offset = state.offset(of: index)
                let old = state.remove(at: index)
                arrayChange?.add(.remove(old.key, at: offset))
            }
            else {
                state[transformed] = count - 1
            }
        }
        for element in change.inserted {
            let transformed = transform(element)
            if let count = state[transformed] {
                state[transformed] = count + 1
            }
            else {
                state[transformed] = 1
                if arrayChange != nil {
                    let offset = state.offset(of: transformed)!
                    arrayChange!.add(.insert(transformed, at: offset))
                }
            }
        }
        if let a = arrayChange, !a.isEmpty {
            signal.send(a)
        }
    }

    override var isBuffered: Bool { return false }
    override subscript(index: Int) -> Element { return state.element(atOffset: index).0 }
    override subscript(bounds: Range<Int>) -> ArraySlice<Element> { return ArraySlice(state.submap(withOffsets: bounds).lazy.map { $0.0 }) }
    override var value: Array<Element> { return Array(state.lazy.map { $0.0 }) }
    override var count: Int { return state.count }
    override var changes: Source<ArrayChange<R>> { return signal.with(retained: self).source }
}
