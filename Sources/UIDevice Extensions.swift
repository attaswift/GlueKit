//
//  UIDevice Extensions.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-03-13.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import UIKit

extension UIDevice {
    public var observableOrientation: AnyObservableValue<UIDeviceOrientation> {
        return ObservableDeviceOrientation(self).anyObservable
    }
}

private final class ObservableDeviceOrientation: _BaseObservableValue<UIDeviceOrientation> {
    let device: UIDevice
    var orientation: UIDeviceOrientation? = nil

    init(_ device: UIDevice) {
        self.device = device
    }

    override var value: UIDeviceOrientation {
        return device.orientation
    }

    var notificationSource: AnySource<Notification> {
        return NotificationCenter.default.source(forName: .UIDeviceOrientationDidChange, sender: device, queue: OperationQueue.main)
    }

    var sink: AnySink<Notification> {
        return MethodSink(owner: self, identifier: 0, method: ObservableDeviceOrientation.receive).anySink
    }

    func receive(_ notification: Notification) {
        beginTransaction()
        let old = orientation!
        let new = device.orientation
        orientation = new
        sendChange(.init(from: old, to: new))
        endTransaction()
    }

    override func activate() {
        device.beginGeneratingDeviceOrientationNotifications()
        orientation = device.orientation
        notificationSource.add(sink)
    }

    override func deactivate() {
        notificationSource.remove(sink)
        device.endGeneratingDeviceOrientationNotifications()
        orientation = nil
    }
}

extension UIDevice {
    public var observableBatteryState: AnyObservableValue<(UIDeviceBatteryState, Float)> {
        if let observable = objc_getAssociatedObject(self, &batteryKey) as? ObservableBatteryState {
            return observable.anyObservable
        }
        let observable = ObservableBatteryState(self)
        objc_setAssociatedObject(self, &batteryKey, observable, .OBJC_ASSOCIATION_RETAIN)
        return observable.anyObservable
    }
}

private var batteryKey: UInt8 = 0

private final class ObservableBatteryState: _BaseObservableValue<(UIDeviceBatteryState, Float)> {
    typealias Value = (UIDeviceBatteryState, Float)

    unowned let device: UIDevice
    var state: Value? = nil
    var didEnableBatteryMonitoring = false

    init(_ device: UIDevice) {
        self.device = device
    }

    override var value: Value {
        return (device.batteryState, device.batteryLevel)
    }

    var batteryStateSource: AnySource<Notification> {
        return NotificationCenter.default.source(forName: .UIDeviceBatteryStateDidChange, sender: device, queue: OperationQueue.main)
    }
    var batteryLevelSource: AnySource<Notification> {
        return NotificationCenter.default.source(forName: .UIDeviceBatteryLevelDidChange, sender: device, queue: OperationQueue.main)
    }

    var sink: AnySink<Notification> {
        return MethodSink(owner: self, identifier: 0, method: ObservableBatteryState.receive).anySink
    }

    func receive(_ notification: Notification) {
        let old = state!
        let new = (device.batteryState, device.batteryLevel)
        if old != new {
            beginTransaction()
            state = new
            sendChange(.init(from: old, to: new))
            endTransaction()
        }
    }

    override func activate() {
        if !device.isBatteryMonitoringEnabled {
            device.isBatteryMonitoringEnabled = true
            didEnableBatteryMonitoring = true
        }
        state = (device.batteryState, device.batteryLevel)
        batteryStateSource.add(sink)
        batteryLevelSource.add(sink)
    }

    override func deactivate() {
        batteryStateSource.remove(sink)
        batteryLevelSource.remove(sink)
        if didEnableBatteryMonitoring {
            device.isBatteryMonitoringEnabled = false
            didEnableBatteryMonitoring = false
        }
        state = nil
    }
}

extension UIDevice {
    public var observableProximityState: AnyObservableValue<Bool> {
        if let observable = objc_getAssociatedObject(self, &proximityKey) as? ObservableDeviceProximity {
            return observable.anyObservable
        }
        let observable = ObservableDeviceProximity(self)
        objc_setAssociatedObject(self, &proximityKey, observable, .OBJC_ASSOCIATION_RETAIN)
        return observable.anyObservable
    }
}

private var proximityKey: UInt8 = 0

private final class ObservableDeviceProximity: _BaseObservableValue<Bool> {
    unowned let device: UIDevice
    
    var state: Bool? = nil
    var didEnableProximityMonitoring = false

    init(_ device: UIDevice) {
        self.device = device
    }

    override var value: Bool {
        return device.proximityState
    }

    var notificationSource: AnySource<Notification> {
        return NotificationCenter.default.source(forName: .UIDeviceProximityStateDidChange, sender: device, queue: OperationQueue.main)
    }

    var sink: AnySink<Notification> {
        return MethodSink(owner: self, identifier: 0, method: ObservableDeviceProximity.receive).anySink
    }

    func receive(_ notification: Notification) {
        beginTransaction()
        let old = state!
        let new = device.proximityState
        state = new
        sendChange(.init(from: old, to: new))
        endTransaction()
    }

    override func activate() {
        if !device.isProximityMonitoringEnabled {
            device.isProximityMonitoringEnabled = true
            didEnableProximityMonitoring = true
        }
        state = device.proximityState
        notificationSource.add(sink)
    }

    override func deactivate() {
        notificationSource.remove(sink)
        if didEnableProximityMonitoring {
            device.isProximityMonitoringEnabled = false
            didEnableProximityMonitoring = false
        }
        state = nil
    }
}

