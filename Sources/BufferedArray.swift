//
//  BufferedArray.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-22.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableArrayType {
    public func buffered() -> ObservableArray<Element> {
        if isBuffered {
            return observableArray
        }
        else {
            return BufferedObservableArray(self).observableArray
        }
    }
}

internal class BufferedObservableArray<Content: ObservableArrayType>: ObservableArrayBase<Content.Element> {
    typealias Element = Content.Element
    typealias Change = ArrayChange<Element>

    private let _content: Content
    private var _value: [Element]
    private var _connection: Connection? = nil
    private var _state = TransactionState<Change>()
    private var _valueState = TransactionState<ValueChange<[Element]>>()
    private var _pendingChange: Change? = nil

    init(_ content: Content) {
        _content = content
        _value = content.value
        super.init()
        _connection = content.updates.connect { [unowned self] update in self.apply(update) }
    }

    deinit {
        _connection!.disconnect()
    }

    private func apply(_ update: ArrayUpdate<Element>) {
        switch update {
        case .beginTransaction:
            _state.begin()
        case .change(let change):
            if _pendingChange != nil {
                _pendingChange!.merge(with: change)
            }
            else {
                _pendingChange = change
            }
        case .endTransaction:
            if let change = _pendingChange {
                if _valueState.isConnected {
                    let old = _value
                    _value.apply(change)
                    _pendingChange = nil
                    let new = _value
                    _valueState.sendLater(ValueChange(from: old, to: new))
                    _state.send(change)
                    _valueState.sendNow()
                }
                else {
                    _value.apply(change)
                    _pendingChange = nil
                    _state.send(change)
                }
            }
            _state.end()
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

    override var updates: Source<Update<Change>> {
        return _state.source(retaining: self)
    }

    override var observable: Observable<[Element]> {
        return Observable(getter: { self.value },
                          updates: { self._valueState.source(retaining: self) })
    }
}
