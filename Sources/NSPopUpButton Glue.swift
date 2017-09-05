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

public func <-- <Value>(target: GlueForNSPopUpButton, model: NSPopUpButton.Choices<Value>) {
    target.setChoices(value: model.value, choices: model.choices)
}

extension NSPopUpButton {
    public struct Choices<Value: Equatable> {
        let value: AnyUpdatableValue<Value>
        let choices: AnyObservableArray<(label: String, value: Value)>

        public init<U: UpdatableValueType, C: ObservableArrayType>(value: U, choices: C) where U.Value == Value, C.Element == (label: String, value: Value) {
            self.value = value.anyUpdatableValue
            self.choices = choices.anyObservableArray
        }

        public init<U: UpdatableValueType, S: Sequence>(value: U, choices: S) where U.Value == Value, S.Element == (label: String, value: Value) {
            self.value = value.anyUpdatableValue
            self.choices = AnyObservableArray.constant(Array(choices))
        }

        public init<U: UpdatableValueType>(value: U, choices: [String: Value]) where U.Value == Value {
            self.value = value.anyUpdatableValue
            self.choices = AnyObservableArray.constant(Array(choices.map { ($0.key, $0.value) }))
        }
    }
}

open class GlueForNSPopUpButton: GlueForNSButton {
    private var object: NSPopUpButton { return owner as! NSPopUpButton }

    private var valueConnection: Connection? = nil
    private var choicesConnection: Connection? = nil
    private var update: (Any?) -> Void = { _ in }

    fileprivate func setChoices<Value: Equatable, U: UpdatableValueType, C: ObservableArrayType>(of type: Value.Type = Value.self, value: U, choices: C) where U.Value == Value, C.Element == (label: String, value: Value) {

        valueConnection?.disconnect()
        choicesConnection?.disconnect()

        update = { newValue in
            guard let v = newValue as? Value else { return }
            value.value = v
        }

        choicesConnection = choices.anyObservableValue.values.subscribe { [unowned self] choices in
            let menu = NSMenu()
            choices.forEach { choice in
                let item = NSMenuItem(title: choice.label, action: #selector(GlueForNSPopUpButton.choiceAction(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = choice.value
                menu.addItem(item)
            }
            self.object.menu = menu
        }

        valueConnection = value.values.subscribe { [unowned self] newValue in
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
