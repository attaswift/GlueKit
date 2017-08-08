//
//  DistinctUnion.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-04.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension ObservableArrayType where Element: Hashable {
    /// Returns an observable set that contains the same elements as this array.
    public func distinctUnion() -> AnyObservableSet<Element> {
        return DistinctUnion<Self>(self).anyObservableSet
    }
}

private class DistinctUnion<Input: ObservableArrayType>: _BaseObservableSet<Input.Element>
where Input.Element: Hashable {
    typealias Element = Input.Element
    typealias Change = SetChange<Element>

    private struct DistinctSink: UniqueOwnedSink {
        typealias Owner = DistinctUnion
        
        unowned(unsafe) let owner: Owner
        
        func receive(_ update: ArrayUpdate<Input.Element>) {
            owner.apply(update)
        }
    }
    
    private let input: Input
    private var members = Dictionary<Element, Int>()

    init(_ input: Input) {
        self.input = input
        super.init()
        for element in input.value {
            _ = self.add(element)
        }
        input.updates.add(DistinctSink(owner: self))
    }

    deinit {
        input.updates.remove(DistinctSink(owner: self))
    }

    func apply(_ update: ArrayUpdate<Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            var setChange = SetChange<Element>()
            for mod in change.modifications {
                mod.forEachOldElement {
                    if remove($0) {
                        setChange.remove($0)
                    }
                }
                mod.forEachNewElement {
                    if add($0) {
                        setChange.insert($0)
                    }
                }
            }
            if !setChange.isEmpty {
                sendChange(setChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }

    private func add(_ element: Element) -> Bool {
        if let old = self.members[element] {
            self.members[element] = old + 1
            return false
        }
        self.members[element] = 1
        return true
    }

    private func remove(_ element: Element) -> Bool {
        let old = self.members[element]!
        if old == 1 {
            self.members[element] = nil
            return true
        }
        self.members[element] = old - 1
        return false
    }

    override var isBuffered: Bool { return true }
    override var count: Int { return value.count }
    override var value: Set<Element> { return Set(members.keys) }
    override func contains(_ element: Element) -> Bool { return members[element] != nil }
    override func isSubset(of other: Set<Element>) -> Bool {
        guard count <= other.count else { return false }
        for (key, _) in members {
            guard other.contains(key) else { return false }
        }
        return true
    }
    override func isSuperset(of other: Set<Element>) -> Bool {
        guard count >= other.count else { return false }
        for element in other {
            guard members[element] != nil else { return false }
        }
        return true
    }
}
