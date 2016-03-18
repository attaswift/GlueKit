//
//  UIGestureRecognizer Extensions.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-03-16.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import UIKit

private var associatedObjectKey: UInt8 = 0

extension UIGestureRecognizer {
    public class func create() -> Self {
        let target = GestureRecognizerTarget()
        let result = self.init(target: target, action: #selector(GestureRecognizerTarget.gestureRecognizerDidFire))
        objc_setAssociatedObject(self, &associatedObjectKey, target, .OBJC_ASSOCIATION_RETAIN)
        return result
    }

    public var recognizedSource: Source<Void> {
        if let target = objc_getAssociatedObject(self, &associatedObjectKey) as? GestureRecognizerTarget {
            return target.signal.source
        }
        let target = GestureRecognizerTarget()
        self.addTarget(target, action: #selector(GestureRecognizerTarget.gestureRecognizerDidFire))
        objc_setAssociatedObject(self, &associatedObjectKey, target, .OBJC_ASSOCIATION_RETAIN)
        return target.signal.source
    }
}

private class GestureRecognizerTarget: NSObject {
    var signal = LazySignal<Void>()

    @objc func gestureRecognizerDidFire() {
        signal.send()
    }
}
