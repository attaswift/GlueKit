//
//  SetMappingForValue.swift
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
    public func injectiveMap<R: Hashable>(_ transform: @escaping (Element) -> R) -> ObservableSet<R> {
        return InjectiveSetMappingForValue(base: self, transform: transform).observableSet
    }
}

private final class InjectiveSetMappingForValue<S: ObservableSetType, Element: Hashable>: ObservableSetBase<Element> {
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

extension ObservableSetType {
    /// Return an observable set that contains the results of mapping the given closure over the elements of this set.
    ///
    /// - Parameter transform: A mapping closure. `transform` does not need to be an injection; elements where
    ///     `transform` returns the same result will be collapsed into a single entry in the result set.
    ///
    /// - SeeAlso: `injectivelyMap(_:)` for a slightly faster variant for when the mapping is injective.
    public func map<R: Hashable>(_ transform: @escaping (Element) -> R) -> ObservableSet<R> {
        return SetMappingForValue(base: self, transform: transform).observableSet
    }
}

private final class SetMappingForValue<S: ObservableSetType, Element: Hashable>: MultiObservableSet<Element> {
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

extension ObservableSetType {
    /// Given an observable set and a closure that extracts an observable value from each element,
    /// return an observable set that contains the extracted field values contained in this set.
    ///
    /// - Parameter key: A mapping closure, extracting an observable value from an element of this set.
    public func map<Field: ObservableValueType>(_ key: @escaping (Element) -> Field) -> ObservableSet<Field.Value> where Field.Value: Hashable {
        return SetMappingForValueField<Self, Field>(base: self, key: key).observableSet
    }
}

class SetMappingForValueField<S: ObservableSetType, Field: ObservableValueType>: MultiObservableSet<Field.Value> where Field.Value: Hashable {
    let base: S
    let key: (S.Element) -> Field

    var baseConnection: Connection? = nil
    var connections: [S.Element: Connection] = [:]

    init(base: S, key: @escaping (S.Element) -> Field) {
        self.base = base
        self.key = key
        super.init()
        baseConnection = base.changes.connect { [unowned self] change in self.apply(change) }

        for e in base.value {
            let field = key(e)
            connections[e] = field.changes.connect { [unowned self] change in self.apply(change) }
            _ = self.insert(field.value)
        }
    }

    deinit {
        baseConnection?.disconnect()
        connections.forEach { (_, c) in c.disconnect() }
    }

    private func apply(_ change: SetChange<S.Element>) {
        var transformedChange = SetChange<Element>()
        for e in change.removed {
            let field = key(e)
            let value = field.value
            connections.removeValue(forKey: e)!.disconnect()
            if self.remove(value) {
                transformedChange.remove(value)
            }
        }
        for e in change.inserted {
            let field = key(e)
            let value = field.value
            let c = field.changes.connect { [unowned self] change in self.apply(change) }
            guard connections.updateValue(c, forKey: e) == nil else { fatalError("Invalid change: inserted element already in set") }
            if self.insert(value) {
                transformedChange.insert(value)
            }
        }
        if !transformedChange.isEmpty {
            signal.send(transformedChange)
        }
    }

    private func apply(_ change: SimpleChange<Field.Value>) {
        if change.old == change.new { return }
        var transformedChange = SetChange<Element>()
        if self.remove(change.old) {
            transformedChange.remove(change.old)
        }
        if self.insert(change.new) {
            transformedChange.insert(change.new)
        }
        if !transformedChange.isEmpty {
            signal.send(transformedChange)
        }
    }
}

extension ObservableSetType {
    public func flatMap<Result: Sequence>(_ key: @escaping (Element) -> Result) -> ObservableSet<Result.Iterator.Element> where Result.Iterator.Element: Hashable {
        return SetMappingForSequence<Self, Result>(base: self, key: key).observableSet
    }
}

class SetMappingForSequence<S: ObservableSetType, Result: Sequence>: MultiObservableSet<Result.Iterator.Element> where Result.Iterator.Element: Hashable {
    typealias Element = Result.Iterator.Element
    let base: S
    let key: (S.Element) -> Result

    var baseConnection: Connection? = nil

    init(base: S, key: @escaping (S.Element) -> Result) {
        self.base = base
        self.key = key
        super.init()
        baseConnection = base.changes.connect { [unowned self] change in self.apply(change) }

        for e in base.value {
            for new in key(e) {
                _ = self.insert(new)
            }
        }
    }

    deinit {
        baseConnection?.disconnect()
    }

    private func apply(_ change: SetChange<S.Element>) {
        var transformedChange = SetChange<Element>()
        for e in change.removed {
            for old in key(e) {
                if self.remove(old) {
                    transformedChange.remove(old)
                }
            }
        }
        for e in change.inserted {
            for new in key(e) {
                if self.insert(new) {
                    transformedChange.insert(new)
                }
            }
        }
        if !transformedChange.isEmpty {
            signal.send(transformedChange)
        }
    }
}

extension ObservableSetType {
    public func flatMap<Field: ObservableSetType>(_ key: @escaping (Element) -> Field) -> ObservableSet<Field.Element> {
        return SetMappingForSetField<Self, Field>(base: self, key: key).observableSet
    }
}

class SetMappingForSetField<S: ObservableSetType, Field: ObservableSetType>: MultiObservableSet<Field.Element> {
    let base: S
    let key: (S.Element) -> Field

    var baseConnection: Connection? = nil
    var connections: [S.Element: Connection] = [:]

    init(base: S, key: @escaping (S.Element) -> Field) {
        self.base = base
        self.key = key
        super.init()
        baseConnection = base.changes.connect { [unowned self] change in self.apply(change) }

        for e in base.value {
            let field = key(e)
            connections[e] = field.changes.connect { [unowned self] change in self.apply(change) }
            for new in field.value {
                _ = self.insert(new)
            }
        }
    }

    deinit {
        baseConnection?.disconnect()
        connections.forEach { (_, c) in c.disconnect() }
    }

    private func apply(_ change: SetChange<S.Element>) {
        var transformedChange = SetChange<Element>()
        for e in change.removed {
            let field = key(e)
            connections.removeValue(forKey: e)!.disconnect()
            for r in field.value {
                if self.remove(r) {
                    transformedChange.remove(r)
                }
            }
        }
        for e in change.inserted {
            let field = key(e)
            let c = field.changes.connect { [unowned self] change in self.apply(change) }
            guard connections.updateValue(c, forKey: e) == nil else { fatalError("Invalid change: inserted element already in set") }
            for i in field.value {
                if self.insert(i) {
                    transformedChange.insert(i)
                }
            }
        }
        if !transformedChange.isEmpty {
            signal.send(transformedChange)
        }
    }

    private func apply(_ change: SetChange<Field.Element>) {
        var transformedChange = SetChange<Element>()
        for old in change.removed {
            if self.remove(old) {
                transformedChange.remove(old)
            }
        }
        for new in change.inserted {
            if self.insert(new) {
                transformedChange.insert(new)
            }
        }
        if !transformedChange.isEmpty {
            signal.send(transformedChange)
        }
    }
}

extension ObservableSetType {
    public func flatMap<Field: ObservableArrayType>(_ key: @escaping (Element) -> Field) -> ObservableSet<Field.Element> where Field.Element: Hashable {
        return SetMappingForArrayField<Self, Field>(base: self, key: key).observableSet
    }
}

class SetMappingForArrayField<S: ObservableSetType, Field: ObservableArrayType>: MultiObservableSet<Field.Element> where Field.Element: Hashable {
    let base: S
    let key: (S.Element) -> Field

    var baseConnection: Connection? = nil
    var connections: [S.Element: Connection] = [:]

    init(base: S, key: @escaping (S.Element) -> Field) {
        self.base = base
        self.key = key
        super.init()
        baseConnection = base.changes.connect { [unowned self] change in self.apply(change) }

        for e in base.value {
            let field = key(e)
            connections[e] = field.changes.connect { [unowned self] change in self.apply(change) }
            for new in field.value {
                _ = self.insert(new)
            }
        }
    }

    deinit {
        baseConnection?.disconnect()
        connections.forEach { (_, c) in c.disconnect() }
    }

    private func apply(_ change: SetChange<S.Element>) {
        var transformedChange = SetChange<Element>()
        for e in change.removed {
            let field = key(e)
            connections.removeValue(forKey: e)!.disconnect()
            for r in field.value {
                if self.remove(r) {
                    transformedChange.remove(r)
                }
            }
        }
        for e in change.inserted {
            let field = key(e)
            let c = field.changes.connect { [unowned self] change in self.apply(change) }
            guard connections.updateValue(c, forKey: e) == nil else { fatalError("Invalid change: inserted element already in set") }
            for i in field.value {
                if self.insert(i) {
                    transformedChange.insert(i)
                }
            }
        }
        if !transformedChange.isEmpty {
            signal.send(transformedChange)
        }
    }

    private func apply(_ change: ArrayChange<Field.Element>) {
        var transformedChange = SetChange<Element>()
        change.forEachOld { old in
            if self.remove(old) {
                transformedChange.remove(old)
            }
        }
        change.forEachNew { new in
            if self.insert(new) {
                transformedChange.insert(new)
            }
        }
        transformedChange = transformedChange.removingEqualChanges()
        if !transformedChange.isEmpty {
            signal.send(transformedChange)
        }
    }
}
