//
//  SetMappingForValue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-05.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableSetType where Change == SetChange<Element> {
    /// Return an observable set that contains the results of injectively mapping the given closure over the elements of this set.
    ///
    /// - Parameter transform: A mapping closure. `transform` must be an injection; if it maps two nonequal elements into
    ///     the same result, the transformation may trap or it may return invalid results.
    ///
    /// - SeeAlso: `map(_:)` for a slightly slower variant for use when the mapping is not injective.
    public func injectiveMap<R: Hashable>(_ transform: @escaping (Element) -> R) -> AnyObservableSet<R> {
        return InjectiveSetMappingForValue(parent: self, transform: transform).anyObservableSet
    }
}

private struct InjectiveSink<Parent: ObservableSetType, Element: Hashable>: UniqueOwnedSink where Parent.Change == SetChange<Parent.Element> {
    typealias Owner = InjectiveSetMappingForValue<Parent, Element>

    unowned(unsafe) let owner: Owner

    func receive(_ update: SetUpdate<Parent.Element>) {
        owner.apply(update)
    }
}

private final class InjectiveSetMappingForValue<Parent: ObservableSetType, Element: Hashable>: _BaseObservableSet<Element>where Parent.Change == SetChange<Parent.Element> {
    typealias Change = SetChange<Element>

    let parent: Parent
    let transform: (Parent.Element) -> Element

    private var _value: Set<Element> = []

    init(parent: Parent, transform: @escaping (Parent.Element) -> Element) {
        self.parent = parent
        self.transform = transform
        super.init()

        _value = Set(parent.value.map(transform))
        parent.add(InjectiveSink(owner: self))
    }

    deinit {
        parent.remove(InjectiveSink(owner: self))
    }

    func apply(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            let mappedChange = SetChange(removed: Set(change.removed.lazy.map(transform)),
                                         inserted: Set(change.inserted.lazy.map(transform)))
            precondition(mappedChange.removed.count == change.removed.count, "injectiveMap: transformation is not injective; use map() instead")
            precondition(mappedChange.inserted.count == change.inserted.count, "injectiveMap: transformation is not injective; use map() instead")
            _value.apply(mappedChange)
            if !mappedChange.isEmpty {
                sendChange(mappedChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }

    override var isBuffered: Bool { return true }
    override var count: Int { return parent.count }
    override var value: Set<Element> { return _value }
    override func contains(_ member: Element) -> Bool { return _value.contains(member) }
    override func isSubset(of other: Set<Element>) -> Bool { return _value.isSubset(of: other) }
    override func isSuperset(of other: Set<Element>) -> Bool { return _value.isSuperset(of: other) }
}

extension ObservableSetType where Change == SetChange<Element> {
    /// Return an observable set that contains the results of mapping the given closure over the elements of this set.
    ///
    /// - Parameter transform: A mapping closure. `transform` does not need to be an injection; elements where
    ///     `transform` returns the same result will be collapsed into a single entry in the result set.
    ///
    /// - SeeAlso: `injectivelyMap(_:)` for a slightly faster variant for when the mapping is injective.
    public func map<R: Hashable>(_ transform: @escaping (Element) -> R) -> AnyObservableSet<R> {
        return SetMappingForValue(parent: self, transform: transform).anyObservableSet
    }
}

private struct MapSink<Parent: ObservableSetType, Element: Hashable>: UniqueOwnedSink where Parent.Change == SetChange<Parent.Element> {
    typealias Owner = SetMappingForValue<Parent, Element>

    unowned(unsafe) let owner: Owner

    func receive(_ update: SetUpdate<Parent.Element>) {
        owner.apply(update)
    }
}

private final class SetMappingForValue<Parent: ObservableSetType, Element: Hashable>: SetMappingBase<Element> where Parent.Change == SetChange<Parent.Element> {
    typealias Change = SetChange<Element>

    let parent: Parent
    let transform: (Parent.Element) -> Element

    private var connection: Connection? = nil

    init(parent: Parent, transform: @escaping (Parent.Element) -> Element) {
        self.parent = parent
        self.transform = transform
        super.init()
        for element in parent.value {
            _ = self.insert(transform(element))
        }
        parent.updates.add(MapSink(owner: self))
    }

    deinit {
        parent.updates.remove(MapSink(owner: self))
    }

    func apply(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
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
                sendChange(mappedChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }
}
