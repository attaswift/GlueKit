//
//  NSNotificationCenter Support.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension NotificationCenter {
    /// Creates a Source that observes the specified notifications and forwards it to its connected sinks.
    ///
    /// The returned source holds strong references to the notification center and the sender (if any).
    /// The source will only observe the notification while a sink is actually connected.
    ///
    /// - Parameter name: The name of the notification to observe.
    /// - Parameter sender: The sender of the notifications to observe, or nil for any object. This parameter is nil by default.
    /// - Parameter queue: The operation queue on which the source will trigger. If you pass nil, the sinks are run synchronously on the thread that posted the notification. This parameter is nil by default.
    /// - Returns: A Source that triggers when the specified notification is posted.
    public func source(forName name: NSNotification.Name, sender: AnyObject? = nil, queue: OperationQueue? = nil) -> AnySource<Notification> {
        return NotificationSource(center: self, name: name, sender: sender, queue: queue).anySource
    }
}

@objc private class NotificationSource: NSObject, SourceType {
    typealias Value = Notification

    let center: NotificationCenter
    let name: NSNotification.Name
    let sender: AnyObject?
    let queue: OperationQueue?

    let signal = Signal<Notification>()

    init(center: NotificationCenter, name: NSNotification.Name, sender: AnyObject?, queue: OperationQueue?) {
        self.center = center
        self.name = name
        self.sender = sender
        self.queue = queue
    }

    func add<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Notification {
        let first = signal.add(sink)
        if first {
            center.addObserver(self, selector: #selector(didReceive(_:)), name: name, object: sender)
        }
        return first
    }

    func remove<Sink: SinkType>(_ sink: Sink) -> Bool where Sink.Value == Notification {
        let last = signal.remove(sink)
        if last {
            center.removeObserver(self, name: name, object: sender)
        }
        return last
    }

    @objc private func didReceive(_ notification: Notification) {
        if let queue = queue {
            queue.addOperation {
                self.signal.send(notification)
            }
        }
        else {
            self.signal.send(notification)
        }
    }
}
