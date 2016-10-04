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
    internal var orientationSource: Source<UIDeviceOrientation> {
        if let signal = objc_getAssociatedObject(self, &orientationKey) as? Signal<UIDeviceOrientation> {
            return signal.source
        }
        let nc = NotificationCenter.default
        var observer: NSObjectProtocol? = nil
        let signal = Signal<UIDeviceOrientation>(
            start: { [unowned self] signal in
                precondition(observer == nil)
                self.beginGeneratingDeviceOrientationNotifications()
                observer = nc.addObserver(forName: .UIDeviceOrientationDidChange, object: self, queue: OperationQueue.main) { [unowned signal] notification in
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

    public var observableOrientation: Observable<UIDeviceOrientation> {
        return Observable(getter: { self.orientation },
                          changes: {
                            var orientation = self.orientation
                            return self.orientationSource.map { value in
                                defer { orientation = value }
                                return SimpleChange<UIDeviceOrientation>(from: orientation, to: value) }
        })
    }

    public var batterySource: Source<(UIDeviceBatteryState, Float)> {
        if let signal = objc_getAssociatedObject(self, &batteryKey) as? Signal<(UIDeviceBatteryState, Float)> {
            return signal.source
        }
        let nc = NotificationCenter.default
        var stateObserver: NSObjectProtocol? = nil
        var levelObserver: NSObjectProtocol? = nil
        let signal = Signal<(UIDeviceBatteryState, Float)>(
            start: { [unowned self] signal in
                precondition(stateObserver == nil && levelObserver == nil)
                precondition(!self.isBatteryMonitoringEnabled)
                self.isBatteryMonitoringEnabled = true
                stateObserver = nc.addObserver(forName: .UIDeviceBatteryStateDidChange, object: self, queue: OperationQueue.main) { [unowned signal] notification in
                    signal.send((self.batteryState, self.batteryLevel))
                }
                levelObserver = nc.addObserver(forName: .UIDeviceBatteryLevelDidChange, object: self, queue: OperationQueue.main) { [unowned signal] notification in
                    signal.send((self.batteryState, self.batteryLevel))
                }
            },
            stop: { [unowned self] signal in
                nc.removeObserver(stateObserver!)
                nc.removeObserver(levelObserver!)
                stateObserver = nil
                levelObserver = nil
                self.isBatteryMonitoringEnabled = false
            }
        )
        objc_setAssociatedObject(self, &batteryKey, signal, .OBJC_ASSOCIATION_RETAIN)
        return signal.source
    }

    public var proximitySource: Source<Bool> {
        if let signal = objc_getAssociatedObject(self, &proximityKey) as? Signal<Bool> {
            return signal.source
        }

        let nc = NotificationCenter.default
        var observer: NSObjectProtocol? = nil
        let signal = Signal<Bool>(
            start: { [unowned self] signal in
                precondition(observer == nil)
                precondition(!self.isProximityMonitoringEnabled)
                self.isProximityMonitoringEnabled = true
                observer = nc.addObserver(forName: .UIDeviceProximityStateDidChange, object: self, queue: OperationQueue.main) { [unowned signal] notification in
                    signal.send(self.proximityState)
                }
            },
            stop: { [unowned self] signal in
                nc.removeObserver(observer!)
                observer = nil
                self.isProximityMonitoringEnabled = false
            }
        )
        objc_setAssociatedObject(self, &proximityKey, signal, .OBJC_ASSOCIATION_RETAIN)
        return signal.source
    }
}


