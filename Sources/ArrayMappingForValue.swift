//
//  ArrayMappingForValue.swift
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

private final class ArrayMappingForValue<Element, Input: ObservableArrayType>: ObservableArrayBase<Element> {
    typealias Change = ArrayChange<Element>

    let input: Input
    let transform: (Input.Element) -> Element

    init(input: Input, transform: @escaping (Input.Element) -> Element) {
        self.input = input
        self.transform = transform
        super.init()
    }

    override var isBuffered: Bool {
        return false
    }

    override subscript(index: Int) -> Element {
        return transform(input[index])
    }

    override subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        return ArraySlice(input[bounds].map(transform))
    }
    
    override var count: Int {
        return input.count
    }

    override var value: [Element] {
        return input.value.map(transform)
    }

    override var changeEvents: Source<ChangeEvent<Change>> {
        return input.changeEvents.map { $0.map { $0.map(self.transform) } }
    }

    override var observableCount: Observable<Int> {
        return input.observableCount
    }
}


extension ObservableArrayType {
    public func bufferedMap<Output>(_ transform: @escaping (Element) -> Output) -> ObservableArray<Output> {
        return BufferedArrayMappingForValue(self, transform: transform).observableArray
    }
}

private class BufferedArrayMappingForValue<Input, Output, Content: ObservableArrayType>: ObservableArrayBase<Output> where Content.Element == Input {
    typealias Element = Output
    typealias Change = ArrayChange<Output>

    let content: Content
    let transform: (Input) -> Output
    private var _value: [Output]
    private var connection: Connection? = nil
    private var changeSignal = ChangeSignal<Change>()

    init(_ content: Content, transform: @escaping (Input) -> Output) {
        self.content = content
        self.transform = transform
        self._value = content.value.map(transform)
        super.init()
        self.connection = content.changeEvents.connect { [unowned self] event in self.apply(event) }
    }

    deinit {
        connection!.disconnect()
    }

    private func apply(_ event: ChangeEvent<ArrayChange<Input>>) {
        switch event {
        case .willChange:
            changeSignal.willChange()
        case .didNotChange:
            changeSignal.didNotChange()
        case .didChange(let change):
            precondition(change.initialCount == value.count)
            if changeSignal.isConnected {
                var mappedChange = Change(initialCount: value.count)
                for modification in change.modifications {
                    switch modification {
                    case .insert(let new, at: let index):
                        let tnew = transform(new)
                        mappedChange.add(.insert(tnew, at: index))
                        _value.insert(tnew, at: index)
                    case .remove(_, at: let index):
                        let old = _value.remove(at: index)
                        mappedChange.add(.remove(old, at: index))
                    case .replace(_, at: let index, with: let new):
                        let old = value[index]
                        let tnew = transform(new)
                        _value[index] = tnew
                        mappedChange.add(.replace(old, at: index, with: tnew))
                    case .replaceSlice(let old, at: let index, with: let new):
                        let range = index ..< index + old.count
                        let told = Array(value[range])
                        let tnew = new.map(transform)
                        mappedChange.add(.replaceSlice(told, at: index, with: tnew))
                        _value.replaceSubrange(range, with: tnew)
                    }
                }
                changeSignal.didChange(mappedChange)
            }
            else {
                // If the signal isn't connected, we don't need to generate a mapped change; we can just tell the signal that we didn't change, while applying the change directly.
                changeSignal.didNotChange()
                for modification in change.modifications {
                    switch modification {
                    case .insert(let new, at: let index):
                        _value.insert(transform(new), at: index)
                    case .remove(_, at: let index):
                        _value.remove(at: index)
                    case .replace(_, at: let index, with: let new):
                        _value[index] = transform(new)
                    case .replaceSlice(let old, at: let index, with: let new):
                        _value.replaceSubrange(index ..< index + old.count, with: new.map(transform))
                    }
                }
            }
        }
    }

    override var isBuffered: Bool {
        return true
    }

    override subscript(_ index: Int) -> Element {
        return value[index]
    }

    override subscript(_ range: Range<Int>) -> ArraySlice<Element> {
        return value[range]
    }

    override var value: [Element] { return _value }

    override var count: Int {
        return value.count
    }

    override var changeEvents: Source<ChangeEvent<Change>> {
        return changeSignal.source(holding: self)
    }
}


