//
//  UIBarButtonItem Extensions.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-04-09.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import UIKit

private var associatedObjectKey: UInt8 = 0
private let listenerAction = #selector(TargetActionListener.actionDidFire)

extension UIBarButtonItem: SourceType {
    public convenience init(barButtonSystemItem systemItem: UIBarButtonSystemItem) {
        let target = TargetActionListener()
        self.init(barButtonSystemItem: systemItem, target: target, action: listenerAction)
        objc_setAssociatedObject(self, &associatedObjectKey, target, .OBJC_ASSOCIATION_RETAIN)
    }

    public var connecter: (Sink<Void>) -> Connection {
        if let target = objc_getAssociatedObject(self, &associatedObjectKey) as? TargetActionListener {
            return target.signal.source.connecter
        }
        let target = TargetActionListener()
        self.target = target
        self.action = listenerAction
        objc_setAssociatedObject(self, &associatedObjectKey, target, .OBJC_ASSOCIATION_RETAIN)
        return target.signal.connecter
    }

    public convenience init(image: UIImage?, style: UIBarButtonItemStyle) {
        let target = TargetActionListener()
        self.init(image: image, style: style, target: target, action: listenerAction)
        objc_setAssociatedObject(self, &associatedObjectKey, target, .OBJC_ASSOCIATION_RETAIN)
    }

    public convenience init(image: UIImage?, landscapeImagePhone: UIImage?, style: UIBarButtonItemStyle) {
        let target = TargetActionListener()
        self.init(image: image, landscapeImagePhone: landscapeImagePhone, style: style, target: target, action: listenerAction)
        objc_setAssociatedObject(self, &associatedObjectKey, target, .OBJC_ASSOCIATION_RETAIN)
    }

    public convenience init(title: String?, style: UIBarButtonItemStyle) {
        let target = TargetActionListener()
        self.init(title: title, style: style, target: target, action: listenerAction)
        objc_setAssociatedObject(self, &associatedObjectKey, target, .OBJC_ASSOCIATION_RETAIN)
    }
}

private class TargetActionListener: NSObject {
    var signal = LazySignal<Void>()

    @objc func actionDidFire() {
        signal.send()
    }
}
