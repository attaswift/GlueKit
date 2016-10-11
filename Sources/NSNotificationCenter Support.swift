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
    public func source(forName name: NSNotification.Name, sender: AnyObject? = nil, queue: OperationQueue? = nil) -> Source<Notification> {
        let lock = Lock()
        var observer: NSObjectProtocol? = nil

        let signal = Signal<Notification>(
            start: { signal in
                lock.withLock {
                    precondition(observer == nil)
                    observer = self.addObserver(forName: name, object: sender, queue: queue) { [unowned signal] notification in
                        signal.send(notification)
                    }
                }
            },
            stop: { signal in
                lock.withLock {
                    precondition(observer != nil)
                    self.removeObserver(observer!)
                    observer = nil
                }
        })

        return signal.source
    }
}
