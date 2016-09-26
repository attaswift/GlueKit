//
//  CADisplayLink Extensions.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-03-17.
//  Copyright © 2016 Károly Lőrentey.
//

import QuartzCore

private var associatedTargetKey: UInt8 = 0

extension CADisplayLink: SourceType {
    public static func create() -> CADisplayLink {
        let target = DisplayLinkTarget()
        let displayLink = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick(_:)))
        target.displayLink = UnownedReference(displayLink)
        objc_setAssociatedObject(displayLink, &associatedTargetKey, target, .OBJC_ASSOCIATION_RETAIN)
        return displayLink
    }

    private var target: DisplayLinkTarget {
        guard let target = objc_getAssociatedObject(self, &associatedTargetKey) as? DisplayLinkTarget else {
            preconditionFailure("Use CADisplayLink.create() to create the display link")
        }
        return target
    }

    public var connecter: (Sink<CADisplayLink>) -> Connection {
        return target.signal.connecter
    }
}

private class DisplayLinkTarget: NSObject, SignalDelegate {
    var displayLink: UnownedReference<CADisplayLink>! = nil
    var runLoop: RunLoop? = nil

    lazy var signal: Signal<CADisplayLink> = { Signal<CADisplayLink>(delegate: self) }()

    @objc fileprivate func tick(_ displayLink: CADisplayLink) {
        precondition(displayLink == self.displayLink.value)
        signal.send(displayLink)
    }

    fileprivate func start(_ signal: Signal<CADisplayLink>) {
        precondition(self.runLoop == nil)
        let runLoop = RunLoop.current
        self.runLoop = runLoop
        displayLink.value.add(to: runLoop, forMode: RunLoopMode.commonModes)
    }

    fileprivate func stop(_ signal: Signal<CADisplayLink>) {
        precondition(runLoop != nil)
        displayLink.value.remove(from: runLoop!, forMode: RunLoopMode.commonModes)
        runLoop = nil
    }
}
