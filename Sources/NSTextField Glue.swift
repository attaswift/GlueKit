//
//  NSTextField Glue.swift
//  macOS
//
//  Created by Károly Lőrentey on 2017-09-05.
//  Copyright © 2017 Károly Lőrentey. All rights reserved.
//

#if os(macOS)
import AppKit

extension NSTextField {
    @objc open dynamic override var glue: GlueForNSTextField { return _glue() }
}

public func <-- <V: UpdatableValueType>(target: GlueForNSTextField.ValidatingValueReceiver, model: V) where V.Value: LosslessStringConvertible {
    target.glue.setModel(model)
}

open class GlueForNSTextField: GlueForNSControl {
    private var object: NSTextField { return owner as! NSTextField }
    private var delegate: Any? = nil

    public struct ValidatingValueReceiver { let glue: GlueForNSTextField }
    public var value: ValidatingValueReceiver { return ValidatingValueReceiver(glue: self) }

    fileprivate func setModel<V: UpdatableValueType>(_ model: V) where V.Value: LosslessStringConvertible {
        if let delegate = self.delegate as? GlueKitTextFieldDelegate<V.Value> {
            delegate.model = model.anyUpdatableValue
        }
        else {
            let delegate = GlueKitTextFieldDelegate(object, model)
            self.delegate = delegate
        }
    }
}

class GlueKitTextFieldDelegate<Value: LosslessStringConvertible>: NSObject, NSTextFieldDelegate {
    unowned let view: NSTextField
    var model: AnyUpdatableValue<Value> {
        didSet { reconnect() }
    }

    init<V: UpdatableValueType>(_ view: NSTextField, _ model: V) where V.Value == Value {
        self.view = view
        self.model = model.anyUpdatableValue
        super.init()
        reconnect()
    }

    private var modelConnection: Connection? = nil
    private func reconnect() {
        view.delegate = self
        modelConnection?.disconnect()
        modelConnection = model.values.subscribe { [unowned self] value in
            self.view.stringValue = "\(value)"
        }
    }

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        return Value(view.stringValue) != nil
    }

    override func controlTextDidEndEditing(_ obj: Notification) {
        if let value = Value(view.stringValue) {
            model.value = value
        }
        else {
            view.stringValue = "\(model.value)"
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        view.stringValue = "\(model.value)"
        //textView.window?.makeFirstResponder(nil)
        return true
    }
}
#endif
