//
//  TimerSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015–2017 Károly Lőrentey.
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
        self.init(timespec: spec)
    }
}

extension DispatchQueue {
    func async(afterDelay interval: TimeInterval, execute block: @escaping @convention(block) () -> Void) {
        self.asyncAfter(deadline: DispatchTime.now() + interval, execute: block)
    }

    func async(after date: Date, execute block: @escaping @convention(block) () -> Void) {
        self.asyncAfter(wallDeadline: DispatchWallTime(date), execute: block)
    }
}

private class AtomicToken {
    // TODO: This should use atomics, which are currently (Xcode 8 beta 5) unavailable in Swift
    private let lock = Lock()
    private var token: Int = 0

    @discardableResult
    func increment() -> Int {
        return lock.withLock {
            token += 1
            return token
        }
    }

    func equals(_ value: Int) -> Bool {
        return lock.withLock {
            return token == value
        }
    }
}

public typealias TimerSource = _TimerSource<Void>

/// A Source that is firing at customizable intervals. The time of the each firing is determined by a user-supplied closure.
///
/// The timer interval should be relatively large (at least multiple seconds); this is not supposed to be a realtime timer.
///
/// Note that this source will only schedule an actual timer while there are sinks connected to it.
public final class _TimerSource<Dummy>: SignalerSource<Void> {

    private let queue: DispatchQueue
    private let next: () -> Date?
    private var token = AtomicToken()

    override func activate() {
        start()
    }

    override func deactivate() {
        stop()
    }

    /// Set up a new TimerSource that is scheduled on a given queue at the times determined by the supplied block.
    /// @param queue The queue on which to schedule the timer. 
    ///    The signal will fire on this queue. If unspecified, the main queue is used.
    /// @param next A closure that returns the next date the signal is supposed to fire, 
    ///    or nil if the timer should be paused indefinitely. The closure is executed on the queue in the first parameter.
    ///
    /// Note that the `next` closure will not be called immediately; the source waits for the first connection 
    /// before establishing a timer.
    public init(queue: DispatchQueue = DispatchQueue.main, next: @escaping () -> Date?) {
        self.queue = queue
        self.next = next
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

    private func scheduleNext(_ frozenToken: Int) {
        guard token.equals(frozenToken) else { return }
        if let nextDate = next() {
            queue.async(after: nextDate) { [weak self] in self?.fireWithToken(frozenToken) }
        }
    }

    private func fireWithToken(_ frozenToken: Int) {
        guard token.equals(frozenToken) else { return }
        self.signal.send()
        scheduleNext(frozenToken)
    }
}

/// Encapsulates information on a periodic timer and associated logic to determine firing dates.
/// Tries to prevent timer drift by using walltime-based, absolute firing dates instead of relative ones.
private struct PeriodicTimerData {
    let start: Date
    let interval: TimeInterval

    var currentTick: Int {
        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(start))
        let tick = floor(elapsed / interval)
        return Int(tick)
    }

    var dateOfNextTick: Date {
        return start.addingTimeInterval(TimeInterval(currentTick + 1) * interval)
    }
}

public extension _TimerSource {
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
