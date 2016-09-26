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

internal class BufferedObservableArray<Content: ObservableArrayType>: ObservableArrayType, ObservableType {
    typealias Element = Content.Element
    typealias Change = ArrayChange<Element>

    let content: Content
    private(set) var value: [Element]
    private var connection: Connection!
    private var valueSignal = OwningSignal<[Element]>()

    init(_ content: Content) {
        self.content = content
        self.value = content.value
        self.connection = content.futureChanges.connect { [weak self] change in
            guard let this = self else { return }
            this.value.apply(change)
            this.valueSignal.sendIfConnected(this.value)
        }
    }

    var isBuffered: Bool { return true }

    subscript(_ index: Int) -> Content.Element {
        return value[index]
    }

    subscript(_ range: Range<Int>) -> ArraySlice<Content.Element> {
        return value[range]
    }

    var count: Int {
        return value.count
    }

    var futureChanges: Source<ArrayChange<Content.Element>> {
        return content.futureChanges
    }

    var futureValues: Source<[Element]> {
        return valueSignal.with(retained: self).source
    }

    var observable: Observable<Array<Content.Element>> {
        return Observable(self)
    }
}

