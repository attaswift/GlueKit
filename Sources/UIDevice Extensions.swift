//
//  UIDevice Extensions.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-03-13.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import UIKit

private var orientationKey: UInt8 = 0
private var batteryKey: UInt8 = 0
private var proximityKey: UInt8 = 0

extension UIDevice {
    public var orientationSource: Source<UIDeviceOrientation> {
        if let signal = objc_getAssociatedObject(self, &orientationKey) as? Signal<UIDeviceOrientation> {
            return signal.source
        }
        let nc = NSNotificationCenter.defaultCenter()
        var observer: NSObjectProtocol? = nil
        let signal = Signal<UIDeviceOrientation>(
            start: { [unowned self] signal in
                precondition(observer == nil)
                self.beginGeneratingDeviceOrientationNotifications()
                observer = nc.addObserverForName(UIDeviceOrientationDidChangeNotification, object: nil, queue: NSOperationQueue.mainQueue()) { [unowned signal] notification in
                    signal.send(self.orientation)
                }
            },
            stop: { [unowned self] signal in
                nc.removeObserver(observer!)
                observer = nil
                self.endGeneratingDeviceOrientationNotifications()
            }
        )
        objc_setAssociatedObject(self, &orientationKey, signal, .OBJC_ASSOCIATION_RETAIN)
        return signal.source
    }

    public var batterySource: Source<(UIDeviceBatteryState, Float)> {
        if let signal = objc_getAssociatedObject(self, &batteryKey) as? Signal<(UIDeviceBatteryState, Float)> {
            return signal.source
        }
        let nc = NSNotificationCenter.defaultCenter()
        var stateObserver: NSObjectProtocol? = nil
        var levelObserver: NSObjectProtocol? = nil
        let signal = Signal<(UIDeviceBatteryState, Float)>(
            start: { [unowned self] signal in
                precondition(stateObserver == nil && levelObserver == nil)
                precondition(!self.batteryMonitoringEnabled)
                self.batteryMonitoringEnabled = true
                stateObserver = nc.addObserverForName(UIDeviceBatteryStateDidChangeNotification, object: nil, queue: NSOperationQueue.mainQueue()) { [unowned signal] notification in
                    signal.send((self.batteryState, self.batteryLevel))
                }
                levelObserver = nc.addObserverForName(UIDeviceBatteryLevelDidChangeNotification, object: nil, queue: NSOperationQueue.mainQueue()) { [unowned signal] notification in
                    signal.send((self.batteryState, self.batteryLevel))
                }
            },
            stop: { [unowned self] signal in
                nc.removeObserver(stateObserver!)
                nc.removeObserver(levelObserver!)
                stateObserver = nil
                levelObserver = nil
                self.batteryMonitoringEnabled = false
            }
        )
        objc_setAssociatedObject(self, &batteryKey, signal, .OBJC_ASSOCIATION_RETAIN)
        return signal.source
    }

    public var proximitySource: Source<Bool> {
        if let signal = objc_getAssociatedObject(self, &proximityKey) as? Signal<Bool> {
            return signal.source
        }

        let nc = NSNotificationCenter.defaultCenter()
        var observer: NSObjectProtocol? = nil
        let signal = Signal<Bool>(
            start: { [unowned self] signal in
                precondition(observer == nil)
                precondition(!self.proximityMonitoringEnabled)
                self.proximityMonitoringEnabled = true
                observer = nc.addObserverForName(UIDeviceProximityStateDidChangeNotification, object: nil, queue: NSOperationQueue.mainQueue()) { [unowned signal] notification in
                    signal.send(self.proximityState)
                }
            },
            stop: { [unowned self] signal in
                nc.removeObserver(observer!)
                observer = nil
                self.proximityMonitoringEnabled = false
            }
        )
        objc_setAssociatedObject(self, &proximityKey, signal, .OBJC_ASSOCIATION_RETAIN)
        return signal.source
    }
}


