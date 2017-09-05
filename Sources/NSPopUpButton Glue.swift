//
//  NSPopUpButton Glue.swift
//  macOS
//
//  Created by Károly Lőrentey on 2017-09-05.
//  Copyright © 2017 Károly Lőrentey. All rights reserved.
//

#if os(macOS)
import AppKit

extension NSPopUpButton {
    @objc open dynamic override var glue: GlueForNSPopUpButton { return _glue() }
}

public func <-- <Value>(target: GlueForNSPopUpButton, choices: NSPopUpButton.Choices<Value>) {
    target.setChoices(choices)
}

extension NSPopUpButton {
    public struct Choices<Value: Equatable> {
        let model: AnyUpdatableValue<Value>
        let values: AnyObservableArray<(label: String, value: Value)>

        public init<U: UpdatableValueType, C: ObservableArrayType>(model: U, values: C) where U.Value == Value, C.Element == (label: String, value: Value) {
            self.model = model.anyUpdatableValue
            self.values = values.anyObservableArray
        }

        public init<U: UpdatableValueType, S: Sequence>(model: U, values: S) where U.Value == Value, S.Element == (label: String, value: Value) {
            self.model = model.anyUpdatableValue
            self.values = AnyObservableArray.constant(Array(values))
        }

        public init<U: UpdatableValueType>(model: U, values: DictionaryLiteral<String, Value>) where U.Value == Value {
            self.model = model.anyUpdatableValue
            self.values = AnyObservableArray.constant(Array(values.map { ($0.key, $0.value) }))
        }
    }
}

open class GlueForNSPopUpButton: GlueForNSButton {
    private var object: NSPopUpButton { return owner as! NSPopUpButton }

    private var valueConnection: Connection? = nil
    private var choicesConnection: Connection? = nil
    private var update: (Any?) -> Void = { _ in }

    fileprivate func setChoices<Value>(_ choices: NSPopUpButton.Choices<Value>) {

        valueConnection?.disconnect()
        choicesConnection?.disconnect()

        update = { value in if let value = value as? Value { choices.model.value = value } }

        choicesConnection = choices.values.anyObservableValue.values.subscribe { [unowned self] choices in
            let menu = NSMenu()
            choices.forEach { choice in
                let item = NSMenuItem(title: choice.label, action: #selector(GlueForNSPopUpButton.choiceAction(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = choice.value
                menu.addItem(item)
            }
            self.object.menu = menu
        }

        valueConnection = choices.model.values.subscribe { [unowned self] newValue in
            if let item = self.object.menu?.items.first(where: { $0.representedObject as? Value == newValue }) {
                if self.object.selectedItem != item {
                    self.object.select(item)
                }
            }
            else {
                self.object.select(nil)
            }
        }
    }

    @IBAction func choiceAction(_ sender: NSMenuItem) {
        update(sender.representedObject)
    }
}
#endif
