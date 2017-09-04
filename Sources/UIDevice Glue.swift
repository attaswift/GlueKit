//
//  UIDevice Glue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-03-13.
//  Copyright © 2015–2017 Károly Lőrentey.
//

#if os(iOS)
import UIKit

extension UIDevice {
    open override var glue: GlueForUIDevice {
        return _glue()
    }
}

open class GlueForUIDevice: GlueForNSObject {
    private var object: UIDevice { return owner as! UIDevice }

    public lazy var orientation: AnyObservableValue<UIDeviceOrientation>
        = ObservableDeviceOrientation(self.object).anyObservableValue

    public lazy var batteryState: AnyObservableValue<(UIDeviceBatteryState, Float)>
        = ObservableBatteryState(self.object).anyObservableValue

    public lazy var proximityState: AnyObservableValue<Bool>
        = ObservableDeviceProximity(self.object).anyObservableValue
}

private struct DeviceOrientationSink: UniqueOwnedSink {
    typealias Owner = ObservableDeviceOrientation

    unowned let owner: Owner

    func receive(_ notification: Notification) {
        owner.receive(notification)
    }
}

private final class ObservableDeviceOrientation: _BaseObservableValue<UIDeviceOrientation> {
    unowned let device: UIDevice
    var orientation: UIDeviceOrientation? = nil

    init(_ device: UIDevice) {
        self.device = device
    }

    override var value: UIDeviceOrientation {
        return device.orientation
    }

    lazy var notificationSource: AnySource<Notification> = NotificationCenter.default.glue.source(forName: .UIDeviceOrientationDidChange, sender: self.device, queue: OperationQueue.main)

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
        notificationSource.add(DeviceOrientationSink(owner: self))
    }

    override func deactivate() {
        notificationSource.remove(DeviceOrientationSink(owner: self))
        device.endGeneratingDeviceOrientationNotifications()
        orientation = nil
    }
}

private struct BatteryStateSink: UniqueOwnedSink {
    typealias Owner = ObservableBatteryState

    unowned let owner: Owner

    func receive(_ notification: Notification) {
        owner.receive(notification)
    }
}

private var batteryKey: UInt8 = 0

private final class ObservableBatteryState: _BaseObservableValue<(UIDeviceBatteryState, Float)> {
    typealias Value = (UIDeviceBatteryState, Float)

    unowned let device: UIDevice
    var state: Value? = nil
    var didEnableBatteryMonitoring = false

    lazy var batteryStateSource: AnySource<Notification> = NotificationCenter.default.glue.source(forName: .UIDeviceBatteryStateDidChange, sender: self.device, queue: OperationQueue.main)
    lazy var batteryLevelSource: AnySource<Notification> = NotificationCenter.default.glue.source(forName: .UIDeviceBatteryLevelDidChange, sender: self.device, queue: OperationQueue.main)

    init(_ device: UIDevice) {
        self.device = device
    }

    override var value: Value {
        return (device.batteryState, device.batteryLevel)
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
        batteryStateSource.add(BatteryStateSink(owner: self))
        batteryLevelSource.add(BatteryStateSink(owner: self))
    }

    override func deactivate() {
        batteryStateSource.remove(BatteryStateSink(owner: self))
        batteryLevelSource.remove(BatteryStateSink(owner: self))
        if didEnableBatteryMonitoring {
            device.isBatteryMonitoringEnabled = false
            didEnableBatteryMonitoring = false
        }
        state = nil
    }
}

private struct DeviceProximitySink: UniqueOwnedSink {
    typealias Owner = ObservableDeviceProximity

    unowned let owner: Owner

    func receive(_ notification: Notification) {
        owner.receive(notification)
    }
}

private var proximityKey: UInt8 = 0

private final class ObservableDeviceProximity: _BaseObservableValue<Bool> {
    unowned let device: UIDevice
    
    var state: Bool? = nil
    var didEnableProximityMonitoring = false

    lazy var notificationSource: AnySource<Notification> = NotificationCenter.default.glue.source(forName: .UIDeviceProximityStateDidChange, sender: self.device, queue: OperationQueue.main)

    init(_ device: UIDevice) {
        self.device = device
    }

    override var value: Bool {
        return device.proximityState
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
        notificationSource.add(DeviceProximitySink(owner: self))
    }

    override func deactivate() {
        notificationSource.remove(DeviceProximitySink(owner: self))
        if didEnableProximityMonitoring {
            device.isProximityMonitoringEnabled = false
            didEnableProximityMonitoring = false
        }
        state = nil
    }
}
#endif
