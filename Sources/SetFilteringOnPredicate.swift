//
//  SetFilteringOnPredicate.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-12.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

extension ObservableSetType where Change == SetChange<Element> {
    public func filter(_ isIncluded: @escaping (Element) -> Bool) -> AnyObservableSet<Element> {
        return SetFilteringOnPredicate<Self>(parent: self, test: isIncluded).anyObservableSet
    }

    public func filter<Predicate: ObservableValueType>(_ isIncluded: Predicate) -> AnyObservableSet<Element>
    where Predicate.Value == (Element) -> Bool, Predicate.Change == ValueChange<Predicate.Value> {
        return self.filter(isIncluded.map { predicate -> Optional<(Element) -> Bool> in predicate })
    }

    public func filter<Predicate: ObservableValueType>(_ isIncluded: Predicate) -> AnyObservableSet<Element>
    where Predicate.Value == Optional<(Element) -> Bool>, Predicate.Change == ValueChange<Predicate.Value> {
        let reference: AnyObservableValue<AnyObservableSet<Element>> = isIncluded.map { predicate in
            if let predicate: (Element) -> Bool = predicate {
                return self.filter(predicate).anyObservableSet
            }
            else {
                return self.anyObservableSet
            }
        }
        return reference.unpacked()
    }
}

private struct FilteringSink<Parent: ObservableSetType>: UniqueOwnedSink
where Parent.Change == SetChange<Parent.Element> {
    typealias Owner = SetFilteringOnPredicate<Parent>

    unowned let owner: Owner

    func receive(_ update: SetUpdate<Parent.Element>) {
        owner.applyParentUpdate(update)
    }
}

private final class SetFilteringOnPredicate<Parent: ObservableSetType>: _BaseObservableSet<Parent.Element>
where Parent.Change == SetChange<Parent.Element> {
    public typealias Element = Parent.Element
    public typealias Change = SetChange<Element>

    private let parent: Parent
    private let test: (Element) -> Bool

    private var matchingElements: Set<Element> = []

    init(parent: Parent, test: @escaping (Element) -> Bool) {
        self.parent = parent
        self.test = test
    }

    override var isBuffered: Bool {
        return false
    }
    override var count: Int {
        if isConnected { return matchingElements.count }
        return parent.value.reduce(0) { test($1) ? $0 + 1 : $0 }
    }
    override var value: Set<Element> {
        if isConnected { return matchingElements }
        return Set(self.parent.value.filter(test))
    }
    override func contains(_ member: Element) -> Bool {
        if isConnected { return matchingElements.contains(member) }
        return self.parent.contains(member) && test(member)
    }
    override func isSubset(of other: Set<Element>) -> Bool {
        if isConnected { return matchingElements.isSubset(of: other) }
        for member in self.parent.value {
            guard test(member) else { continue }
            guard other.contains(member) else { return false }
        }
        return true
    }
    override func isSuperset(of other: Set<Element>) -> Bool {
        if isConnected { return matchingElements.isSuperset(of: other) }
        for member in other {
            guard test(member) && parent.contains(member) else { return false }
        }
        return true
    }

    override func activate() {
        for e in parent.value {
            if test(e) {
                matchingElements.insert(e)
            }
        }
        parent.add(FilteringSink(owner: self))
    }

    override func deactivate() {
        parent.remove(FilteringSink(owner: self))
        matchingElements = []
    }

    func applyParentUpdate(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            var c = SetChange<Element>()
            for e in change.removed {
                if let old = matchingElements.remove(e) {
                    c.remove(old)
                }
            }
            for e in change.inserted {
                if self.test(e) {
                    matchingElements.insert(e)
                    c.insert(e)
                }
            }
            if !c.isEmpty {
                sendChange(c)
            }
        case .endTransaction:
            endTransaction()
        }
    }
}
