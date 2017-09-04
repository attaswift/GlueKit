//
//  UIControl Glue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-03-11.
//  Copyright © 2015–2017 Károly Lőrentey.
//

#if os(iOS)
import UIKit
import SipHash

private var associatedObjectKey: Int8 = 0

extension UIControl {
    open override var glue: GlueForUIControl {
        return _glue()
    }
}

open class GlueForUIControl: GlueForNSObject {
    private struct ControlEventsTargetKey: SipHashable {
        let sink: AnySink<UIEvent>
        let events: UIControlEvents
        
        func appendHashes(to hasher: inout SipHasher) {
            hasher.append(sink)
            hasher.append(events.rawValue)
        }
        
        static func ==(left: ControlEventsTargetKey, right: ControlEventsTargetKey) -> Bool {
            return left.sink == right.sink && left.events == right.events
        }
    }
    
    private final class ControlEventsTarget: NSObject {
        let sink: AnySink<UIEvent>
        
        init(sink: AnySink<UIEvent>) {
            self.sink = sink
        }
        
        @objc func eventDidTrigger(_ sender: AnyObject, forEvent event: UIEvent) {
            sink.receive(event)
        }
    }
    
    public struct ControlEventsSource: SourceType {
        public typealias Value = UIEvent
        
        public let control: UIControl
        public let events: UIControlEvents
        
        public func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Value {
            let target = control.glue.add(sink.anySink, for: events)
            control.addTarget(target, action: #selector(ControlEventsTarget.eventDidTrigger(_:forEvent:)), for: events)
        }
        
        public func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Value {
            let target = control.glue.remove(sink.anySink, for: events)
            control.removeTarget(target, action: #selector(ControlEventsTarget.eventDidTrigger(_:forEvent:)), for: events)
            return target.sink.opened()!
        }
    }
    
    private var object: UIControl { return owner as! UIControl }

    private var targets: [ControlEventsTargetKey: ControlEventsTarget] = [:]

    public func source(for events: UIControlEvents = .primaryActionTriggered) -> ControlEventsSource {
        return ControlEventsSource(control: object, events: events)
    }

    private func add(_ sink: AnySink<UIEvent>, for events: UIControlEvents) -> ControlEventsTarget {
        let target = ControlEventsTarget(sink: sink)
        let key = ControlEventsTargetKey(sink: sink, events: events)
        precondition(targets[key] == nil)
        targets[key] = target
        return target
    }

    private func remove(_ sink: AnySink<UIEvent>, for events: UIControlEvents) -> ControlEventsTarget {
        let key = ControlEventsTargetKey(sink: sink, events: events)
        let target = targets[key]!
        targets[key] = nil
        return target
    }
}
#endif
