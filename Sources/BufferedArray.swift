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

    let content: Content
    private var _value: [Element]
    private var connection: Connection? = nil
    private var changeSignal = ChangeSignal<Change>()
    private var valueSignal = ChangeSignal<SimpleChange<[Element]>>()

    init(_ content: Content) {
        self.content = content
        self._value = content.value
        super.init()
        self.connection = content.changeEvents.connect { [unowned self] event in self.apply(event) }
    }

    deinit {
        self.connection!.disconnect()
    }

    private func apply(_ event: ChangeEvent<Change>) {
        switch event {
        case .willChange:
            self.changeSignal.willChange()
            self.valueSignal.willChange()
        case .didNotChange:
            self.changeSignal.didNotChange()
            self.valueSignal.didNotChange()
        case .didChange(let change):
            if self.valueSignal.isConnected {
                let old = self._value
                _value.apply(change)
                self.changeSignal.didChange(change)
                self.valueSignal.didChange(.init(from: old, to: _value))
            }
            else {
                self.changeSignal.didChange(change)
                // Nobody is listening on the value observer, so nobody will know if we tell it a little white lie:
                self.valueSignal.didNotChange()
            }
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

    override var changeEvents: Source<ChangeEvent<Change>> {
        return changeSignal.source(holding: self)
    }

    override var observable: Observable<[Element]> {
        return Observable(getter: { self.value },
                          changeEvents: { self.valueSignal.source(holding: self) })
    }
}

