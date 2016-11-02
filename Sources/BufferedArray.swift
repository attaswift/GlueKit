//
//  BufferedArray.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-22.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableArrayType where Change == ArrayChange<Element> {
    public func buffered() -> AnyObservableArray<Element> {
        if isBuffered {
            return anyObservableArray
        }
        return BufferedObservableArray(self).anyObservableArray
    }
}

private struct BufferedSink<Content: ObservableArrayType>: UniqueOwnedSink
where Content.Change == ArrayChange<Content.Element> {
    typealias Owner = BufferedObservableArray<Content>

    unowned(unsafe) let owner: Owner

    func receive(_ update: ArrayUpdate<Content.Element>) {
        owner.applyUpdate(update)
    }
}

internal class BufferedObservableArray<Content: ObservableArrayType>: _BaseObservableArray<Content.Element>
where Content.Change == ArrayChange<Content.Element>  {
    typealias Element = Content.Element
    typealias Change = ArrayChange<Element>

    private let _content: Content
    private var _value: [Element]
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

    func applyUpdate(_ update: ArrayUpdate<Element>) {
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

    override subscript(_ index: Int) -> Content.Element {
        return _value[index]
    }

    override subscript(_ range: Range<Int>) -> ArraySlice<Content.Element> {
        return _value[range]
    }

    override var value: [Element] {
        return _value
    }

    override var count: Int {
        return _value.count
    }
}
