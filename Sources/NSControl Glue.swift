//
//  NSControl Glue.swift
//  macOS
//
//  Created by Károly Lőrentey on 2017-09-05.
//  Copyright © 2017 Károly Lőrentey. All rights reserved.
//

#if os(macOS)
import AppKit

extension NSControl {
    @objc open dynamic override var glue: GlueForNSControl { return _glue() }
}

public func <-- <Value, Model: UpdatableValueType>(target: GlueForNSControl.ValueSlot<Value>, model: Model) where Model.Value == Value {
    target.glue.setValueModel(model.anyUpdatableValue)
}
public func <-- <Value, V: UpdatableValueType>(target: GlueForNSControl.ValueSlot<Value>, model: V) where V.Value == Value? {
    target.glue.setValueModel(model.anyUpdatableValue)
}

public func <-- <Value, Model: ObservableValueType>(target: GlueForNSControl.ConfigSlot<Value>, model: Model) where Model.Value == Value {
    target.glue.setConfigSlot(target.keyPath, to: model.anyObservableValue)
}

    
open class GlueForNSControl: GlueForNSObject {
    private var object: NSControl { return owner as! NSControl }
    private var modelConnection: Connection? = nil
    fileprivate var valueModel: AnyObservableValue<Any?>? = nil {
        didSet {
            modelConnection?.disconnect()
            if let model = valueModel {
                modelConnection = model.values.subscribe { [unowned self] value in
                    self.object.objectValue = value
                }
                object.target = self
                object.action = #selector(GlueForNSControl.controlAction(_:))
            }
        }
    }
    fileprivate var valueUpdater: ((Any?) -> Bool)? = nil

    fileprivate func setValueModel<V>(_ model: AnyUpdatableValue<V>) {
        self.valueUpdater = { value in
            guard let v = value as? V else { return false }
            model.value = v
            return true
        }
        self.valueModel = model.map { $0 as Any? }
    }

    fileprivate func setValueModel<V>(_ model: AnyUpdatableValue<V?>) {
        self.valueUpdater = { value in
            model.value = value as? V
            return true
        }
        self.valueModel = model.map { $0 as Any? }
    }

    @objc func controlAction(_ sender: NSControl) {
        if valueUpdater?(sender.objectValue) != true {
            sender.objectValue = valueModel?.value
        }
    }

    public struct ValueSlot<Value> {
        fileprivate let glue: GlueForNSControl
    }
    
    public var intValue: ValueSlot<Int> { return ValueSlot<Int>(glue: self) }
    public var doubleValue: ValueSlot<Double> { return ValueSlot(glue: self) }
    public var stringValue: ValueSlot<String> { return ValueSlot(glue: self) }
    public var attributedStringValue: ValueSlot<NSAttributedString> { return ValueSlot(glue: self) }

    public struct ConfigSlot<Value> {
        fileprivate let glue: GlueForNSControl
        fileprivate let keyPath: ReferenceWritableKeyPath<NSControl, Value>
    }
    
    var configModels: [AnyKeyPath: Connection] = [:]

    func setConfigSlot<Value>(_ keyPath: ReferenceWritableKeyPath<NSControl, Value>, to model: AnyObservableValue<Value>) {
        let connection = model.values.subscribe { [unowned object] value in
            object[keyPath: keyPath] = value
            _ = object
        }
        configModels.updateValue(connection, forKey: keyPath)?.disconnect()
    }

    public var isEnabled: ConfigSlot<Bool> { return ConfigSlot(glue: self, keyPath: \.isEnabled) }
    public var alignment: ConfigSlot<NSTextAlignment> { return ConfigSlot(glue: self, keyPath: \.alignment) }
    public var font: ConfigSlot<NSFont?> { return ConfigSlot(glue: self, keyPath: \.font) }
    public var lineBreakMode: ConfigSlot<NSParagraphStyle.LineBreakMode> { return ConfigSlot(glue: self, keyPath: \.lineBreakMode) }
    public var usesSingleLineMode: ConfigSlot<Bool> { return ConfigSlot(glue: self, keyPath: \.usesSingleLineMode) }
    public var formatter: ConfigSlot<Formatter?> { return ConfigSlot(glue: self, keyPath: \.formatter) }
    public var baseWritingDirection: ConfigSlot<NSWritingDirection> { return ConfigSlot(glue: self, keyPath: \.baseWritingDirection) }
}
#endif
