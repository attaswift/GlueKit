//
//  UIControl extensions.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-03-11.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import UIKit

extension UIControl {
<<<<<<< Updated upstream
    public var sourceForPrimaryAction: Source<Void> {
        return self.sourceForControlEvents(.PrimaryActionTriggered)
    }

    public func sourceForControlEvents(events: UIControlEvents) -> Source<Void> {
=======
    public var sourceForPrimaryAction: Source<UIEvent> {
        return self.sourceForControlEvents(.primaryActionTriggered)
    }

    public func sourceForControlEvents(_ events: UIControlEvents) -> Source<UIEvent> {
>>>>>>> Stashed changes
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
    let signal = Signal<Void>()

    init(registry: ControlEventsObserverRegistry, events: UIControlEvents) {
        self.registry = registry
        self.events = events
        super.init()
        registry.control.addTarget(self, action: #selector(eventDidTrigger(_:)), forControlEvents: events)
    }

    deinit {
        registry.control.removeTarget(self, action: #selector(eventDidTrigger(_:)), forControlEvents: events)
        registry.removeObserver(for: events)
    }

    var source: Source<Void> {
        return signal.source
    }

<<<<<<< Updated upstream
    @objc func eventDidTrigger(sender: AnyObject) {
        signal.send()
=======
    @objc func eventDidTrigger(_ sender: AnyObject, forEvent event: UIEvent) {
        signal.send(event)
    }

    func start(_ signal: Signal<UIEvent>) {
        registry.control.addTarget(self, action: #selector(eventDidTrigger(_:forEvent:)), for: events)
    }

    func stop(_ signal: Signal<UIEvent>) {
        registry.control.removeTarget(self, action: #selector(eventDidTrigger(_:forEvent:)), for: events)
>>>>>>> Stashed changes
    }
}
