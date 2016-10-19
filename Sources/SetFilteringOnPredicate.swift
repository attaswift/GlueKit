//
//  SetFilteringOnPredicate.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-12.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableSetType {
    public func filter(_ isIncluded: @escaping (Element) -> Bool) -> ObservableSet<Element> {
        return SetFilteringOnPredicate<Self>(parent: self, test: isIncluded).observableSet
    }

    public func filter<Predicate: ObservableValueType>(_ isIncluded: Predicate) -> ObservableSet<Element> where Predicate.Value == (Element) -> Bool {
        return self.filter(isIncluded.map { predicate -> Optional<(Element) -> Bool> in predicate })
    }

    public func filter<Predicate: ObservableValueType>(_ isIncluded: Predicate) -> ObservableSet<Element> where Predicate.Value == Optional<(Element) -> Bool>, Predicate.Change == ValueChange<Predicate.Value> {
        let reference = ObservableSetReference<Element>()
        let connection = isIncluded.values.connect { predicate in
            if let predicate = predicate {
                reference.retarget(to: self.filter(predicate))
            }
            else {
                reference.retarget(to: self)
            }
        }
        return reference.observableSet.holding(connection)
    }
}

private final class SetFilteringOnPredicate<Parent: ObservableSetType>: _ObservableSetBase<Parent.Element>, SignalDelegate {
    public typealias Element = Parent.Element
    public typealias Change = SetChange<Element>

    private let parent: Parent
    private let test: (Element) -> Bool

    private var state = TransactionState<Change>()

    private var active = false
    private var parentConnection: Connection? = nil
    private var matchingElements: Set<Element> = []

    init(parent: Parent, test: @escaping (Element) -> Bool) {
        self.parent = parent
        self.test = test
    }

    override var isBuffered: Bool { return false }
    override var count: Int {
        if active { return matchingElements.count }
        return parent.value.reduce(0) { test($1) ? $0 + 1 : $0 }
    }
    override var value: Set<Element> {
        if active { return matchingElements }
        return Set(self.parent.value.filter(test))
    }
    override func contains(_ member: Element) -> Bool {
        if active { return matchingElements.contains(member) }
        return self.parent.contains(member) && test(member)
    }

    override func isSubset(of other: Set<Element>) -> Bool {
        if active { return matchingElements.isSubset(of: other) }
        for member in self.parent.value {
            guard test(member) else { continue }
            guard other.contains(member) else { return false }
        }
        return true
    }

    override func isSuperset(of other: Set<Element>) -> Bool {
        if active { return matchingElements.isSuperset(of: other) }
        for member in other {
            guard test(member) && parent.contains(member) else { return false }
        }
        return true
    }

    override var updates: SetUpdateSource<Element> { return state.source(retainingDelegate: self) }

    internal func start(_ signal: Signal<Update<Change>>) {
        active = true
        for e in parent.value {
            if test(e) {
                matchingElements.insert(e)
            }
        }
        parentConnection = parent.updates.connect { [unowned self] in self.apply($0) }
    }

    internal func stop(_ signal: Signal<Update<Change>>) {
        active = false
        parentConnection?.disconnect()
        parentConnection = nil
        matchingElements = []
    }

    private func apply(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            state.begin()
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
                state.send(c)
            }
        case .endTransaction:
            state.end()
        }
    }
}
