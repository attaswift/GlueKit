//
//  MappedSet.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-05.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableSetType {
    /// Return an observable set that contains the results of injectively mapping the given closure over the elements of this set.
    ///
    /// - Parameter transform: A mapping closure. `transform` must be an injection; if it maps two nonequal elements into
    ///     the same result, the transformation may trap or it may return invalid results.
    ///
    /// - SeeAlso: `map(_:)` for a slightly slower variant for use when the mapping is not injective.
    public func injectiveMap<R>(_ transform: @escaping (Element) -> R) -> ObservableSet<R> {
        return InjectivelyMappedSet(base: self, transform: transform).observableSet
    }

    /// Return an observable set that contains the results of mapping the given closure over the elements of this set.
    ///
    /// - Parameter transform: A mapping closure. `transform` does not need to be an injection; elements where
    ///     `transform` returns the same result will be collapsed into a single entry in the result set.
    ///
    /// - SeeAlso: `injectivelyMap(_:)` for a slightly faster variant for when the mapping is injective.
    public func map<R>(_ transform: @escaping (Element) -> R) -> ObservableSet<R> {
        return MappedSet(base: self, transform: transform).observableSet
    }
}

private final class InjectivelyMappedSet<S: ObservableSetType, Element: Hashable>: ObservableSetBase<Element> {
    typealias Change = SetChange<Element>

    let base: S
    let transform: (S.Element) -> Element

    private var _value: Set<Element> = []
    private var _connection: Connection? = nil
    private var _signal = OwningSignal<Change>()

    init(base: S, transform: @escaping (S.Element) -> Element) {
        self.base = base
        self.transform = transform
        super.init()

        _value = Set(base.value.map(transform))
        _connection = base.changes.connect { [unowned self] change in self.apply(change) }
    }

    deinit {
        _connection?.disconnect()
    }

    func apply(_ change: SetChange<S.Element>) {
        let mappedChange = SetChange(removed: Set(change.removed.lazy.map(transform)),
                                     inserted: Set(change.inserted.lazy.map(transform)))
        precondition(mappedChange.removed.count == change.removed.count, "injectiveMap: transformation is not injective; use map() instead")
        precondition(mappedChange.inserted.count == change.inserted.count, "injectiveMap: transformation is not injective; use map() instead")
        _value.apply(mappedChange)
        _signal.sendIfConnected(mappedChange)
    }

    override var isBuffered: Bool { return true }
    override var count: Int { return base.count }
    override var value: Set<Element> { return _value }
    override func contains(_ member: Element) -> Bool { return _value.contains(member) }
    override func isSubset(of other: Set<Element>) -> Bool { return _value.isSubset(of: other) }
    override func isSuperset(of other: Set<Element>) -> Bool { return _value.isSuperset(of: other) }

    final override var changes: Source<SetChange<Element>> {
        return _signal.with(retained: self).source
    }
}

private final class MappedSet<S: ObservableSetType, Element: Hashable>: MultiObservableSet<Element> {
    typealias Change = SetChange<Element>

    let base: S
    let transform: (S.Element) -> Element

    private var connection: Connection? = nil

    init(base: S, transform: @escaping (S.Element) -> Element) {
        self.base = base
        self.transform = transform
        super.init()
        for element in base.value {
            _ = self.insert(transform(element))
        }
        connection = base.changes.connect { [unowned self] change in self.apply(change) }
    }

    deinit {
        connection?.disconnect()
    }

    private func apply(_ change: SetChange<S.Element>) {
        var mappedChange = SetChange<Element>()
        for element in change.removed {
            let transformed = transform(element)
            if self.remove(transformed) {
                mappedChange.remove(transformed)
            }
        }
        for element in change.inserted {
            let transformed = transform(element)
            if self.insert(transformed) {
                mappedChange.insert(transformed)
            }
        }
        if !mappedChange.isEmpty {
            signal.send(mappedChange)
        }
    }
}
