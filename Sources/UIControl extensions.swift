//
//  UIControl extensions.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-03-11.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import UIKit

extension UIControl {
    public func sourceForPrimaryAction() -> Source<UIEvent> {
        return self.sourceForControlEvents(.PrimaryActionTriggered)
    }

    public func sourceForControlEvents(events: UIControlEvents) -> Source<UIEvent> {
        let registry = ControlEventsObserverRegistry.registry(for: self)
        let observer = registry.observer(for: events)
        return observer.source
    }
}

internal final class ControlEventsObserverRegistry {
    static private var associatedObjectKey: Int8 = 0

    unowned let control: UIControl
    var observers: [UIControlEvents.RawValue: UnownedReference<ControlEventsObserver>] = [:]

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
        if let observer = observers[events.rawValue]?.value {
            return observer
        }
        let observer = ControlEventsObserver(registry: self, events: events)
        observers[events.rawValue] = UnownedReference(observer)
        return observer
    }

    func removeObserver(for events: UIControlEvents) {
        observers[events.rawValue] = nil
    }
}

@objc internal final class ControlEventsObserver: NSObject, SignalDelegate {
    let registry: ControlEventsObserverRegistry
    let events: UIControlEvents
    var signal = OwningSignal<UIEvent, ControlEventsObserver>()

    init(registry: ControlEventsObserverRegistry, events: UIControlEvents) {
        self.registry = registry
        self.events = events
        super.init()
    }

    deinit {
        registry.removeObserver(for: events)
    }

    var source: Source<UIEvent> {
        return signal.with(self).source
    }

    @objc func eventDidTrigger(sender: AnyObject, forEvent event: UIEvent) {
        signal.send(event)
    }

    func start(signal: Signal<UIEvent>) {
        registry.control.addTarget(self, action: #selector(eventDidTrigger(_:forEvent:)), forControlEvents: events)
    }

    func stop(signal: Signal<UIEvent>) {
        registry.control.removeTarget(self, action: #selector(eventDidTrigger(_:forEvent:)), forControlEvents: events)
    }
}
