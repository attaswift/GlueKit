//
//  UIBarButtonItem Extensions.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-04-09.
//  Copyright © 2015–2017 Károly Lőrentey.
//

#if os(iOS)
import UIKit

private var associatedObjectKey: UInt8 = 0
private let listenerAction = #selector(TargetActionListener.actionDidFire)

extension UIBarButtonItem {

    public var actionSource: AnySource<Void> {
        if let target = objc_getAssociatedObject(self, &associatedObjectKey) as? TargetActionListener {
            return target.signal.anySource
        }
        let target = TargetActionListener()
        self.target = target
        self.action = listenerAction
        objc_setAssociatedObject(self, &associatedObjectKey, target, .OBJC_ASSOCIATION_RETAIN)
        return target.signal.anySource
    }

    public convenience init(barButtonSystemItem systemItem: UIBarButtonSystemItem, actionBlock: (() -> ())? = nil) {
        let target = TargetActionListener()
        self.init(barButtonSystemItem: systemItem, target: target, action: listenerAction)
        objc_setAssociatedObject(self, &associatedObjectKey, target, .OBJC_ASSOCIATION_RETAIN)

        if let actionBlock = actionBlock {
            self.glue.connector.connect(target.signal, to: actionBlock)
        }
    }

    public convenience init(image: UIImage?, style: UIBarButtonItemStyle, actionBlock: (() -> ())? = nil) {
        let target = TargetActionListener()
        self.init(image: image, style: style, target: target, action: listenerAction)
        objc_setAssociatedObject(self, &associatedObjectKey, target, .OBJC_ASSOCIATION_RETAIN)

        if let actionBlock = actionBlock {
            self.glue.connector.connect(target.signal, to: actionBlock)
        }
    }

    public convenience init(image: UIImage?, landscapeImagePhone: UIImage?, style: UIBarButtonItemStyle, actionBlock: (() -> ())? = nil) {
        let target = TargetActionListener()
        self.init(image: image, landscapeImagePhone: landscapeImagePhone, style: style, target: target, action: listenerAction)
        objc_setAssociatedObject(self, &associatedObjectKey, target, .OBJC_ASSOCIATION_RETAIN)

        if let actionBlock = actionBlock {
            self.glue.connector.connect(target.signal, to: actionBlock)
        }
    }

    public convenience init(title: String?, style: UIBarButtonItemStyle, actionBlock: (() -> ())? = nil) {
        let target = TargetActionListener()
        self.init(title: title, style: style, target: target, action: listenerAction)
        objc_setAssociatedObject(self, &associatedObjectKey, target, .OBJC_ASSOCIATION_RETAIN)

        if let actionBlock = actionBlock {
            self.glue.connector.connect(target.signal, to: actionBlock)
        }
    }
}

private class TargetActionListener: NSObject {
    let signal = Signal<Void>()

    @objc func actionDidFire() {
        signal.send()
    }
}
#endif
