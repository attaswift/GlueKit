//
//  TimerSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

// Some convenient extensions for DispatchTime, making it understand Foundation types

extension DispatchWallTime {
    internal init(_ date: Date) {
        let secsSinceEpoch = date.timeIntervalSince1970
        let spec = timespec(
            tv_sec: __darwin_time_t(secsSinceEpoch),
            tv_nsec: Int((secsSinceEpoch - floor(secsSinceEpoch)) * Double(NSEC_PER_SEC))
        )
        self.init(time: spec)
    }
}

extension DispatchQueue {
    func after(when interval: TimeInterval, execute block: @convention(block) () -> Void) {
        self.after(when: DispatchTime.now() + interval, execute: block)
    }

    func after(walltime date: Date, execute block: @convention(block) () -> Void) {
        self.after(walltime: DispatchWallTime(date), execute: block)
    }
}

private class AtomicToken {
    private var token: Int32 = 0

    @discardableResult
    func increment() -> Int32 {
        return OSAtomicIncrement32Barrier(&token)
    }

    func equals(_ value: Int32) -> Bool {
        return OSAtomicCompareAndSwap32Barrier(value, value, &token)
    }
}

/// A Source that is firing at customizable intervals. The time of the each firing is determined by a user-supplied closure.
///
/// The timer interval should be relatively large (at least multiple seconds); this is not supposed to be a realtime timer.
///
/// Note that this source will only schedule an actual timer while there are sinks connected to it.
public final class TimerSource: SourceType, SignalDelegate {
    public typealias SourceValue = Void

    private let queue: DispatchQueue
    private let next: (Void) -> Date?
    private var token = AtomicToken()
    private var signal = OwningSignal<Void, TimerSource>()

    /// Set up a new TimerSource that is scheduled on a given queue at the times determined by the supplied block.
    /// @param queue The queue on which to schedule the timer. 
    ///    The signal will fire on this queue. If unspecified, the main queue is used.
    /// @param next A closure that returns the next date the signal is supposed to fire, 
    ///    or nil if the timer should be paused indefinitely. The closure is executed on the queue in the first parameter.
    ///
    /// Note that the `next` closure will not be called immediately; the source waits for the first connection 
    /// before establishing a timer.
    public init(queue: DispatchQueue = DispatchQueue.main, next: (Void) -> Date?) {
        self.queue = queue
        self.next = next
    }

    public var connecter: (Sink<Void>) -> Connection {
        return self.signal.with(self).connecter
    }

    /// Stop the timer. The timer will not fire again until start() is called.
    public func stop() {
        // Cancel the existing scheduling chain.
        self.token.increment()
    }

    /// Start the timer, or if it is already running, recalculate the next firing date and reschedule the timer immediately.
    /// Call this method when the dependencies of the `next` closure have changed since the last firing, and you want to the timer to apply the changes before it fires next.
    public func start() {
        // Start a new scheduling chain.
        let frozenToken = token.increment()
        queue.async {
            self.scheduleNext(frozenToken)
        }
    }

    internal func start(_ signal: Signal<Void>) {
        self.start()
    }
    internal func stop(_ signal: Signal<Void>) {
        self.stop()
    }

    private func scheduleNext(_ frozenToken: Int32) {
        guard token.equals(frozenToken) else { return }
        if let nextDate = next() {
            queue.after(walltime: nextDate) { [weak self] in self?.fireWithToken(frozenToken) }
        }
    }

    private func fireWithToken(_ frozenToken: Int32) {
        guard token.equals(frozenToken) else { return }
        self.signal.send()
        scheduleNext(frozenToken)
    }
}

/// Encapsulates information on a periodic timer and associated logic to determine firing dates.
/// Tries to prevent timer drift by using walltime-based, absolute firing dates instead of relative ones.
private struct PeriodicTimerData {
    private let start: Date
    private let interval: TimeInterval

    private var currentTick: Int {
        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(start))
        let tick = floor(elapsed / interval)
        return Int(tick)
    }

    private var dateOfNextTick: Date {
        return start.addingTimeInterval(TimeInterval(currentTick + 1) * interval)
    }
}

public extension TimerSource {
    /// Creates a TimerSource that triggers periodically with a specific time interval.
    ///
    /// This source makes an effort to prevent timer drift by scheduling ticks at predetermined absolute time points,
    /// but it only guarantees that ticks happen sometime after their scheduled trigger time, with no upper bound to the delay.
    ///
    /// If the system is busy (or sleeping) some ticks may be skipped.
    ///
    /// @param queue: The queue on which to schedule the timer. The signal will fire on this queue. If unspecified, the main queue is used.
    /// @param start: The time at which the source should fire first, or nil to begin firing `interval` seconds from now.
    /// @param interval: The minimum time period between the beginnings of subsequent firings.
    public convenience init(queue: DispatchQueue = DispatchQueue.main, start: Date? = nil, interval: TimeInterval) {
        assert(interval > 0)

        let data = PeriodicTimerData(start: start ?? Date().addingTimeInterval(interval), interval: interval)
        self.init(queue: queue, next: { [data] in data.dateOfNextTick })
    }
}
