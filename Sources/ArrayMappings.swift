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
        return ArrayMappingForValue(input: self, transform: transform).observableArray
    }
}

class ArrayMappingForValue<Element, Input: ObservableArrayType>: ObservableArrayType {
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

    var changes: Source<ArrayChange<Element>> {
        return input.changes.map { $0.map(self.transform) }
    }

    var observableCount: Observable<Int> {
        return input.observableCount
    }
}


extension ObservableArrayType {
    public func bufferedMap<Output>(_ transform: @escaping (Element) -> Output) -> ObservableArray<Output> {
        return BufferedObservableArrayMap(self, transform: transform).observableArray
    }
}

internal class BufferedObservableArrayMap<Input, Output, Content: ObservableArrayType>: ObservableArrayType where Content.Element == Input {
    typealias Element = Output
    typealias Change = ArrayChange<Output>

    let content: Content
    let transform: (Input) -> Output
    private(set) var value: [Output]
    private var connection: Connection!
    private var changeSignal = OwningSignal<Change>()

    init(_ content: Content, transform: @escaping (Input) -> Output) {
        self.content = content
        self.transform = transform
        self.value = content.value.map(transform)
        self.connection = content.changes.connect { [weak self] change in self?.apply(change) }
    }

    private func apply(_ change: ArrayChange<Input>) {
        precondition(change.initialCount == value.count)
        if changeSignal.isConnected {
            var mappedChange = Change(initialCount: value.count)
            for modification in change.modifications {
                switch modification {
                case .insert(let new, at: let index):
                    let tnew = transform(new)
                    mappedChange.add(.insert(tnew, at: index))
                    value.insert(tnew, at: index)
                case .remove(_, at: let index):
                    let old = value.remove(at: index)
                    mappedChange.add(.remove(old, at: index))
                case .replace(_, at: let index, with: let new):
                    let old = value[index]
                    let tnew = transform(new)
                    value[index] = tnew
                    mappedChange.add(.replace(old, at: index, with: tnew))
                case .replaceSlice(let old, at: let index, with: let new):
                    let told = Array(value[index ..< index + old.count])
                    let tnew = new.map(transform)
                    mappedChange.add(.replaceSlice(told, at: index, with: tnew))
                    value.replaceSubrange(index ..< told.count, with: tnew)
                }
            }
            changeSignal.send(mappedChange)
        }
        else {
            for modification in change.modifications {
                switch modification {
                case .insert(let new, at: let index):
                    value.insert(transform(new), at: index)
                case .remove(_, at: let index):
                    value.remove(at: index)
                case .replace(_, at: let index, with: let new):
                    value[index] = transform(new)
                case .replaceSlice(let old, at: let index, with: let new):
                    value.replaceSubrange(index ..< old.count, with: new.map(transform))
                }
            }
        }
    }

    var isBuffered: Bool { return true }


    subscript(_ index: Int) -> Element {
        return value[index]
    }

    subscript(_ range: Range<Int>) -> ArraySlice<Element> {
        return value[range]
    }

    var count: Int {
        return value.count
    }

    var changes: Source<ArrayChange<Element>> {
        return changeSignal.with(retained: self).source
    }
}


