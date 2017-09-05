//
//  NSControl Glue.swift
//  macOS
//
//  Created by Károly Lőrentey on 2017-09-05.
//  Copyright © 2017 Károly Lőrentey. All rights reserved.
//

import AppKit

extension NSControl {
    @objc open dynamic override var glue: GlueForNSControl { return _glue() }
}

public func <-- <V: UpdatableValueType>(target: GlueForNSControl.IntValueReceiver, model: V) where V.Value == Int {
    target.glue.setModel(model.anyUpdatableValue)
}
public func <-- <V: UpdatableValueType>(target: GlueForNSControl.IntValueReceiver, model: V) where V.Value == Int? {
    target.glue.setModel(model.anyUpdatableValue)
}

public func <-- <V: UpdatableValueType>(target: GlueForNSControl.DoubleValueReceiver, model: V) where V.Value == Double {
    target.glue.setModel(model.anyUpdatableValue)
}
public func <-- <V: UpdatableValueType>(target: GlueForNSControl.DoubleValueReceiver, model: V) where V.Value == Double? {
    target.glue.setModel(model.anyUpdatableValue)
}

public func <-- <V: UpdatableValueType>(target: GlueForNSControl.StringValueReceiver, model: V) where V.Value == String {
    target.glue.setModel(model.anyUpdatableValue)
}
public func <-- <V: UpdatableValueType>(target: GlueForNSControl.StringValueReceiver, model: V) where V.Value == String? {
    target.glue.setModel(model.anyUpdatableValue)
}

public func <-- <V: UpdatableValueType>(target: GlueForNSControl.AttributedStringValueReceiver, model: V) where V.Value == NSAttributedString {
    target.glue.setModel(model.anyUpdatableValue)
}
public func <-- <V: UpdatableValueType>(target: GlueForNSControl.AttributedStringValueReceiver, model: V) where V.Value == NSAttributedString? {
    target.glue.setModel(model.anyUpdatableValue)
}

open class GlueForNSControl: GlueForNSObject {
    private var object: NSControl { return owner as! NSControl }
    private var modelConnection: Connection? = nil
    fileprivate var model: AnyObservableValue<Any?>? = nil {
        didSet {
            modelConnection?.disconnect()
            if let model = model {
                modelConnection = model.values.subscribe { [unowned self] value in
                    self.object.objectValue = value
                }
                object.target = self
                object.action = #selector(GlueForNSControl.controlAction(_:))
            }
        }
    }
    fileprivate var updater: ((Any?) -> Bool)? = nil

    fileprivate func setModel<V>(_ model: AnyUpdatableValue<V>) {
        self.updater = { value in
            guard let v = value as? V else { return false }
            model.value = v
            return true
        }
        self.model = model.map { $0 as Any? }
    }

    fileprivate func setModel<V>(_ model: AnyUpdatableValue<V?>) {
        self.updater = { value in
            model.value = value as? V
            return true
        }
        self.model = model.map { $0 as Any? }
    }

    @objc func controlAction(_ sender: NSControl) {
        if updater?(sender.objectValue) != true {
            sender.objectValue = model?.value
        }
    }

    public struct IntValueReceiver { fileprivate let glue: GlueForNSControl }
    public var intValue: IntValueReceiver { return IntValueReceiver(glue: self) }

    public struct DoubleValueReceiver { fileprivate let glue: GlueForNSControl }
    public var doubleValue: DoubleValueReceiver { return DoubleValueReceiver(glue: self) }

    public struct StringValueReceiver { fileprivate let glue: GlueForNSControl }
    public var stringValue: StringValueReceiver { return StringValueReceiver(glue: self) }

    public struct AttributedStringValueReceiver { fileprivate let glue: GlueForNSControl }
    public var attributedStringValue: AttributedStringValueReceiver { return AttributedStringValueReceiver(glue: self) }
}

