//
//  UIControl extensions.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-03-11.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import UIKit

extension UIControl {
    public func source(for events: UIControlEvents = .primaryActionTriggered) -> AnySource<UIEvent> {
        let registry = ControlEventsObserverRegistry.registry(for: self)
        let observer = registry.observer(for: events)
        return observer.source
    }
}

internal final class ControlEventsObserverRegistry {
    static private var associatedObjectKey: Int8 = 0

    unowned let control: UIControl
    var observers: [UIControlEvents.RawValue: ControlEventsObserver] = [:]

    static func registry(for control: UIControl) -> ControlEventsObserverRegistry {
        if let registry = objc_getAssociatedObject(control, &associatedObjectKey) as? ControlEventsObserverRegistry {
            return registry
        }
        let registry = ControlEventsObserverRegistry(control: control)
        objc_setAssociatedObject(control, &associatedObjectKey, registry, .OBJC_ASSOCIATION_RETAIN)
        return registry
    }

    private init(control: UIControl) {
        self.control = control
    }

    func observer(for events: UIControlEvents) -> ControlEventsObserver {
        if let observer = observers[events.rawValue] {
            return observer
        }
        let observer = ControlEventsObserver(registry: self, events: events)
        observers[events.rawValue] = observer
        return observer
    }

    func removeObserver(for events: UIControlEvents) {
        observers[events.rawValue] = nil
    }
}

@objc internal final class ControlEventsObserver: NSObject {
    let registry: ControlEventsObserverRegistry
    let events: UIControlEvents
    let signal = Signal<UIEvent>()

    init(registry: ControlEventsObserverRegistry, events: UIControlEvents) {
        self.registry = registry
        self.events = events
        super.init()
        registry.control.addTarget(self, action: #selector(ControlEventsObserver.eventDidTrigger(_:forEvent:)), for: events)
    }

    deinit {
        registry.control.removeTarget(self, action: #selector(ControlEventsObserver.eventDidTrigger(_:forEvent:)), for: events)
        registry.removeObserver(for: events)
    }

    var source: AnySource<UIEvent> {
        return signal.anySource
    }

    @objc func eventDidTrigger(_ sender: AnyObject, forEvent event: UIEvent) {
        signal.send(event)
    }
}
