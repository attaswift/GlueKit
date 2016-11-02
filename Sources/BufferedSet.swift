//
//  BufferedSet.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-11-02.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableSetType where Change == SetChange<Element> {
    public func buffered() -> AnyObservableSet<Element> {
        if isBuffered {
            return anyObservableSet
        }
        return BufferedObservableSet(self).anyObservableSet
    }
}

private struct BufferedSink<Content: ObservableSetType>: UniqueOwnedSink
where Content.Change == SetChange<Content.Element> {
    typealias Owner = BufferedObservableSet<Content>

    unowned(unsafe) let owner: Owner

    func receive(_ update: SetUpdate<Content.Element>) {
        owner.applyUpdate(update)
    }
}

internal class BufferedObservableSet<Content: ObservableSetType>: _BaseObservableSet<Content.Element>
where Content.Change == SetChange<Content.Element>  {
    typealias Element = Content.Element
    typealias Change = SetChange<Element>

    private let _content: Content
    private var _value: Set<Element>
    private var _pendingChange: Change? = nil

    init(_ content: Content) {
        _content = content
        _value = content.value
        super.init()
        _content.add(BufferedSink(owner: self))
    }

    deinit {
        _content.remove(BufferedSink(owner: self))
    }

    func applyUpdate(_ update: SetUpdate<Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            if _pendingChange != nil {
                _pendingChange!.merge(with: change)
            }
            else {
                _pendingChange = change
            }
        case .endTransaction:
            if let change = _pendingChange {
                _value.apply(change)
                _pendingChange = nil
                sendChange(change)
            }
            endTransaction()
        }
    }

    override var isBuffered: Bool {
        return true
    }

    override var count: Int {
        return _value.count
    }

    override var value: Set<Element> {
        return _value
    }

    override func contains(_ member: Element) -> Bool {
        return _value.contains(member)
    }

    override func isSubset(of other: Set<Element>) -> Bool {
        return _value.isSubset(of: other)
    }

    override func isSuperset(of other: Set<Element>) -> Bool {
        return _value.isSuperset(of: other)
    }
}
