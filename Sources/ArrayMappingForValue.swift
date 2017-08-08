//
//  ArrayMappingForValue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-22.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension ObservableArrayType {
    public func map<Output>(_ transform: @escaping (Element) -> Output) -> AnyObservableArray<Output> {
        return ArrayMappingForValue(input: self, transform: transform).anyObservableArray
    }
}

private final class ArrayMappingForValue<Element, Input: ObservableArrayType>: _AbstractObservableArray<Element> {
    typealias Change = ArrayChange<Element>

    let input: Input
    let transform: (Input.Element) -> Element
    let updateSource: AnySource<ArrayUpdate<Element>>

    init(input: Input, transform: @escaping (Input.Element) -> Element) {
        self.input = input
        self.transform = transform
        self.updateSource = input.updates.map { u in u.map { c in c.map(transform) } }
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

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        updateSource.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return updateSource.remove(sink)
    }

    override var observableCount: AnyObservableValue<Int> {
        return input.observableCount
    }
}


extension ObservableArrayType {
    public func bufferedMap<Output>(_ transform: @escaping (Element) -> Output) -> AnyObservableArray<Output> {
        return BufferedArrayMappingForValue(self, transform: transform).anyObservableArray
    }
}

private class BufferedArrayMappingForValue<Input, Output, Content: ObservableArrayType>: _BaseObservableArray<Output>
where Content.Element == Input {
    typealias Element = Output
    typealias Change = ArrayChange<Output>

    private struct BufferedMapSink: UniqueOwnedSink {
        typealias Owner = BufferedArrayMappingForValue

        unowned(unsafe) let owner: Owner

        func receive(_ update: ArrayUpdate<Content.Element>) {
            owner.apply(update)
        }
    }

    let content: Content
    let transform: (Input) -> Output
    private var _value: [Output]
    private var pendingChange: ArrayChange<Input>? = nil

    init(_ content: Content, transform: @escaping (Input) -> Output) {
        self.content = content
        self.transform = transform
        self._value = content.value.map(transform)
        super.init()

        content.add(BufferedMapSink(owner: self))
    }

    deinit {
        content.remove(BufferedMapSink(owner: self))
    }

    func apply(_ update: Update<ArrayChange<Input>>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            if pendingChange != nil {
                pendingChange!.merge(with: change)
            }
            else {
                pendingChange = change
            }
        case .endTransaction:
            if let change = pendingChange {
                pendingChange = nil
                if isConnected {
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
                    sendChange(mappedChange)
                }
                else {
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
            endTransaction()
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
}
