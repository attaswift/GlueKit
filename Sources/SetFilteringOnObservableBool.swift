//
//  SetFilteringOnObservableBool.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import SipHash

extension ObservableSetType {
    public func filter<Field: ObservableValueType>(_ isIncluded: @escaping (Element) -> Field) -> AnyObservableSet<Element> where Field.Value == Bool {
        return SetFilteringOnObservableBool<Self, Field>(parent: self, isIncluded: isIncluded).anyObservableSet
    }
}

private class SetFilteringOnObservableBool<Parent: ObservableSetType, Field: ObservableValueType>: _BaseObservableSet<Parent.Element>
where Field.Value == Bool {
    typealias Element = Parent.Element
    typealias Change = SetChange<Element>

    private struct ParentSink: UniqueOwnedSink {
        typealias Owner = SetFilteringOnObservableBool
        
        unowned(unsafe) let owner: Owner
        
        func receive(_ update: SetUpdate<Parent.Element>) {
            owner.applyParentUpdate(update)
        }
    }
    
    private struct FieldSink: SinkType, SipHashable {
        typealias Owner = SetFilteringOnObservableBool
        
        unowned(unsafe) let owner: Owner
        let element: Parent.Element
        
        func receive(_ update: ValueUpdate<Field.Value>) {
            owner.applyFieldUpdate(update, from: element)
        }
        
        func appendHashes(to hasher: inout SipHasher) {
            hasher.append(ObjectIdentifier(owner))
            hasher.append(element)
        }
        
        static func ==(left: FieldSink, right: FieldSink) -> Bool {
            return left.owner === right.owner && left.element == right.element
        }
    }
    
    private let parent: Parent
    private let isIncluded: (Element) -> Field

    private var matchingElements: Set<Element> = []
    private var fieldSinks: Dictionary<FieldSink, Field> = [:]

    init(parent: Parent, isIncluded: @escaping (Element) -> Field) {
        self.parent = parent
        self.isIncluded = isIncluded
    }

    override var isBuffered: Bool { return false }

    override var count: Int {
        if isConnected { return matchingElements.count }
        var count = 0
        for element in parent.value {
            if isIncluded(element).value {
                count += 1
            }
        }
        return count
    }

    override var value: Set<Element> {
        if isConnected { return matchingElements }
        return Set(self.parent.value.filter { isIncluded($0).value })
    }

    override func contains(_ member: Element) -> Bool {
        if isConnected { return matchingElements.contains(member) }
        return self.parent.contains(member) && isIncluded(member).value
    }

    override func isSubset(of other: Set<Element>) -> Bool {
        if isConnected { return matchingElements.isSubset(of: other) }
        for member in self.parent.value {
            guard isIncluded(member).value else { continue }
            guard other.contains(member) else { return false }
        }
        return true
    }

    override func isSuperset(of other: Set<Element>) -> Bool {
        if isConnected { return matchingElements.isSuperset(of: other) }
        for member in other {
            guard isIncluded(member).value && parent.contains(member) else { return false }
        }
        return true
    }

    override func activate() {
        for e in parent.value {
            let test = self.isIncluded(e)
            if test.value {
                matchingElements.insert(e)
            }
            let sink = FieldSink(owner: self, element: e)
            test.add(sink)
            fieldSinks[sink] = test
        }
        parent.add(ParentSink(owner: self))
    }

    override func deactivate() {
        parent.remove(ParentSink(owner: self))
        for (sink, test) in fieldSinks {
            test.remove(sink)
        }
        fieldSinks = [:]
        matchingElements = []
    }

    func applyParentUpdate(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            var c = SetChange<Element>()
            for e in change.removed {
                let sink = FieldSink(owner: self, element: e)
                let test = fieldSinks.removeValue(forKey: sink)!
                test.remove(sink)
                if let old = self.matchingElements.remove(e) {
                    c.remove(old)
                }
            }
            for e in change.inserted {
                let test = self.isIncluded(e)
                let sink = FieldSink(owner: self, element: e)
                test.add(sink)
                let old = fieldSinks.updateValue(test, forKey: sink)
                precondition(old == nil)
                if test.value {
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

    func applyFieldUpdate(_ update: ValueUpdate<Bool>, from element: Parent.Element) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            if !change.old && change.new {
                matchingElements.insert(element)
                sendChange(SetChange(inserted: [element]))
            }
            else if change.old && !change.new {
                matchingElements.remove(element)
                sendChange(SetChange(removed: [element]))
            }
        case .endTransaction:
            endTransaction()
        }
    }
}
