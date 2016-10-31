//
//  CADisplayLink Extensions.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-03-17.
//  Copyright © 2016 Károly Lőrentey.
//

import QuartzCore

private var associatedTargetKey: UInt8 = 0

public class CADisplayLinkSource: SignalerSource<CADisplayLink> {
    public typealias Value = CADisplayLink

    private var runLoop: RunLoop? = nil
    public var displayLink: CADisplayLink? = nil

    public override init() {
        super.init()
    }

    func activate() {
        displayLink = CADisplayLink(target: self, selector: #selector(CADisplayLinkSource.tick(_:)))
        precondition(self.runLoop == nil)
        let runLoop = RunLoop.current
        self.runLoop = runLoop
        displayLink!.add(to: runLoop, forMode: RunLoopMode.commonModes)
    }

    func deactivate() {
        precondition(runLoop != nil)
        displayLink!.remove(from: runLoop!, forMode: RunLoopMode.commonModes)
        displayLink = nil
        runLoop = nil
    }

    @objc private func tick(_ displayLink: CADisplayLink) {
        signal.send(displayLink)
    }
}
