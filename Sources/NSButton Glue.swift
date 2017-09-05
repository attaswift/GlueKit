//
//  NSButton Glue.swift
//  macOS
//
//  Created by Károly Lőrentey on 2017-09-05.
//  Copyright © 2017 Károly Lőrentey. All rights reserved.
//

#if os(macOS)
import AppKit

extension NSButton {
    @objc open dynamic override var glue: GlueForNSButton { return _glue() }
}

public func <-- <V: UpdatableValueType>(target: GlueForNSButton.StateReceiver, model: V) where V.Value == NSControl.StateValue {
    target.glue.model = model.anyUpdatableValue
}

public func <-- <B: UpdatableValueType>(target: GlueForNSButton.StateReceiver, model: B) where B.Value == Bool {
    target.glue.model = model.map({ $0 ? .on : .off }, inverse: { $0 == .off ? false : true })
}

open class GlueForNSButton: GlueForNSControl {
    private var object: NSButton { return owner as! NSButton }

    public struct StateReceiver {
        let glue: GlueForNSButton
    }

    public var state: StateReceiver { return StateReceiver(glue: self) }

    private let modelConnector = Connector()
    fileprivate var model: AnyUpdatableValue<NSControl.StateValue>? {
        didSet {
            modelConnector.disconnect()
            if object.target === self {
                object.target = nil
                object.action = nil
            }
            if let model = model {
                object.target = self
                object.action = #selector(GlueForNSButton.buttonAction(_:))
                modelConnector.connect(model.values) { [unowned self] value in
                    self.object.state = value
                }
            }
        }
    }

    @IBAction func buttonAction(_ sender: NSButton) {
        self.model?.value = sender.state
    }
}
#endif
