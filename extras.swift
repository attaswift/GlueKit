extension SourceType {
    public func throttleOnMainQueue(interval: NSTimeInterval) -> Source<Value> {
        return throttleOn(dispatch_get_main_queue(), interval: interval)
    }

    public func throttleOn(queue: dispatch_queue_t, interval: NSTimeInterval) -> Source<Value> {
        return Source<Value> { sink in
            var lock = Spinlock()
            var pending: Value? = nil
            var last = NSDate()

            return self.connect { value in
                lock.locked {
                    if pending != nil {
                        // We have already scheduled a firing. Update pending value and return.
                        pending = value
                        return
                    }
                    else if last.timeIntervalSinceNow > -interval {
                        // We haven't scheduled a firing, but we fired too recently. Schedule a firing later.
                        pending = value
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(interval * NSTimeInterval(NSEC_PER_SEC))), queue) {
                            let v: Value = lock.locked {
                                // Get the latest value and clear it.
                                let v = pending!
                                pending = nil
                                last = NSDate()
                                return v
                            }
                            sink(v)
                        }
                    }
                    else {
                        // We have no scheduled firing, and we haven't recently fired. Fire now.
                        last = NSDate()
                        dispatch_async(queue) {
                            sink(value)
                        }
                    }
                }
            }
        }
    }
}

extension SourceType where Value: Equatable {
    public func uniq() -> Source<Value> {
        var previous: Value? = nil
        return self.filter { value in
            let p = previous
            previous = value
            return p != .Some(value)
        }
    }
}
