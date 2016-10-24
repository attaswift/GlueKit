//
//  CADisplayLink Extensions.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-03-17.
//  Copyright © 2016 Károly Lőrentey.
//

import QuartzCore

private var associatedTargetKey: UInt8 = 0

public class CADisplayLinkSource: NSObject, SourceType {
    public typealias Value = CADisplayLink

    private var runLoop: RunLoop? = nil
    public var displayLink: CADisplayLink? = nil
    private let signal = Signal<CADisplayLink>()

    public override init() {
        super.init()
    }

    @discardableResult
    public func add<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == CADisplayLink {
        let first = signal.add(sink)
        if first {
            displayLink = CADisplayLink(target: self, selector: #selector(CADisplayLinkSource.tick(_:)))
            precondition(self.runLoop == nil)
            let runLoop = RunLoop.current
            self.runLoop = runLoop
            displayLink!.add(to: runLoop, forMode: RunLoopMode.commonModes)
        }
        return first
    }

    @discardableResult
    public func remove<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == CADisplayLink {
        let last = signal.remove(sink)
        if last {
            precondition(runLoop != nil)
            displayLink!.remove(from: runLoop!, forMode: RunLoopMode.commonModes)
            displayLink = nil
            runLoop = nil
        }
        return last
    }

    @objc private func tick(_ displayLink: CADisplayLink) {
        signal.send(displayLink)
    }
}
