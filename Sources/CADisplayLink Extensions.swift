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

    public var connecter: Sink<CADisplayLink> -> Connection {
        return target.signal.connecter
    }
}

private class DisplayLinkTarget: NSObject, SignalDelegate {
    var displayLink: UnownedReference<CADisplayLink>! = nil
    var runLoop: NSRunLoop? = nil

    lazy var signal: Signal<CADisplayLink> = { Signal<CADisplayLink>(delegate: self) }()

    @objc private func tick(displayLink: CADisplayLink) {
        precondition(displayLink == self.displayLink.value)
        signal.send(displayLink)
    }

    private func start(signal: Signal<CADisplayLink>) {
        precondition(self.runLoop == nil)
        let runLoop = NSRunLoop.currentRunLoop()
        self.runLoop = runLoop
        displayLink.value.addToRunLoop(runLoop, forMode: NSRunLoopCommonModes)
    }

    private func stop(signal: Signal<CADisplayLink>) {
        precondition(runLoop != nil)
        displayLink.value.removeFromRunLoop(runLoop!, forMode: NSRunLoopCommonModes)
        runLoop = nil
    }
}
