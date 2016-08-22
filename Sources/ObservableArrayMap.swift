//
//  ObservableArrayMap.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-22.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableArrayType {
    public func map<Output>(_ transform: @escaping (Element) -> Output) -> ObservableArray<Output> {
        return ObservableArrayMap(input: self, transform: transform).observableArray
    }
}

class ObservableArrayMap<Element, Input: ObservableArrayType>: ObservableArrayType {
    typealias Change = ArrayChange<Element>

    let input: Input
    let transform: (Input.Element) -> Element

    init(input: Input, transform: @escaping (Input.Element) -> Element) {
        self.input = input
        self.transform = transform
    }

    var isBuffered: Bool {
        return false
    }

    var count: Int {
        return input.count
    }

    var value: [Element] {
        return input.value.map(transform)
    }

    subscript(index: Int) -> Element {
        return transform(input[index])
    }

    subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        return ArraySlice(input[bounds].map(transform))
    }

    var futureChanges: Source<ArrayChange<Element>> {
        return input.futureChanges.map { $0.map(self.transform) }
    }

    var observableCount: Observable<Int> {
        return input.observableCount
    }
}
