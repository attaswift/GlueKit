//
//  KVO Support.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public extension SourceType where SourceValue == AnyObject {
    /// Casts all values to Type using an unsafe cast. Signals a fatal error if a value isn't a Type.
    func castedTo<Type: AnyObject>() -> Source<Type> {
        return sourceOperator { value, sink in
            sink.receive(value as! Type)
        }
    }

    /// Casts all values to String via NSString. Signals a fatal error if a value isn't an NSString.
    func toString() -> Source<String> {
        return sourceOperator { value, sink in
            sink.receive(value as! String)
        }
    }

    /// Converts all values to Bool using NSNumber.integerValue. Signals a fatal error if a value isn't an NSNumber.
    func toBool() -> Source<Bool> {
        return sourceOperator { value, sink in
            let v = value as! NSNumber
            sink.receive(v.boolValue)
        }
    }

    /// Converts all values to Int using NSNumber.integerValue. Signals a fatal error if a value isn't an NSNumber.
    func toInt() -> Source<Int> {
        return sourceOperator { value, sink in
            let v = value as! NSNumber
            sink.receive(v.integerValue)
        }
    }

    /// Converts all values to Float using NSNumber.floatValue. Signals a fatal error if a value isn't an NSNumber.
    func toFloat() -> Source<Float> {
        return sourceOperator { value, sink in
            let v = value as! NSNumber
            sink.receive(v.floatValue)
        }
    }

    /// Converts all values to Double using NSNumber.doubleValue. Signals a fatal error if a value isn't an NSNumber.
    func toDouble() -> Source<Double> {
        return sourceOperator { value, sink in
            let v = value as! NSNumber
            sink.receive(v.doubleValue)
        }
    }

#if USE_COREGRAPHICS
    /// Converts all values to CGFloat using NSNumber.doubleValue. Signals a fatal error if a value isn't an NSNumber.
    func toCGFloat() -> Source<CGFloat> {
        return sourceOperator { value, sink in
            let v = value as! NSNumber
            sink.receive(CGFloat(v.doubleValue))
        }
    }

    /// Converts all values to CGPoint using NSValue.CGPointValue. Signals a fatal error if a value isn't an NSValue.
    func toCGPoint() -> Source<CGPoint> {
        return sourceOperator { value, sink in
            let v = value as! NSValue
            sink.receive(v.CGPointValue())
        }
    }

    /// Converts all values to CGSize using NSValue.CGSizeValue. Signals a fatal error if a value isn't an NSValue.
    func toCGSize() -> Source<CGSize> {
        return sourceOperator { value, sink in
            let v = value as! NSValue
            sink.receive(v.CGSizeValue())
        }
    }

    /// Converts all values to CGRect using NSValue.CGRectValue. Signals a fatal error if a value isn't an NSValue.
    func toCGRect() -> Source<CGRect> {
        return sourceOperator { value, sink in
            let v = value as! NSValue
            sink.receive(v.CGRectValue())
        }
    }

    /// Converts all values to CGAffineTransformValue using NSValue.CGAffineTransformValue.  Signals a fatal error if a value isn't an NSValue.
    func toCGAffineTransform() -> Source<CGAffineTransform> {
        return sourceOperator { value, sink in
            let v = value as! NSValue
            sink.receive(v.CGAffineTransformValue())
        }
    }
#endif
}

public extension NSObject {
    /// Returns an observable source for a KVO-compatible key path.
    /// Note that the object is retained by the returned source.
    public func sourceForKeyPath(keyPath: String) -> Source<AnyObject> {
        return KVOObserver.observerForObject(self)._sourceForKeyPath(keyPath)
    }
}

// A single object that observes all key paths currently registered as Sources on a target object.
// Each Source associated with a key path holds a strong reference to this object.
@objc private class KVOObserver: NSObject {
    static private var associatedObjectKey: Int8 = 0

    let object: NSObject

    var mutex = RawMutex()
    var signals: [String: UnownedReference<Signal<AnyObject>>] = [:]
    var observerContext: Int8 = 0

    static func observerForObject(object: NSObject) -> KVOObserver {
        if let observer = objc_getAssociatedObject(object, &associatedObjectKey) as? KVOObserver {
            return observer
        }
        else {
            let observer = KVOObserver(object: object)
            objc_setAssociatedObject(self, &associatedObjectKey, observer, .OBJC_ASSOCIATION_ASSIGN)
            return observer
        }
    }

    init(object: NSObject) {
        self.object = object
        super.init()
    }

    deinit {
        objc_setAssociatedObject(object, &KVOObserver.associatedObjectKey, nil, .OBJC_ASSOCIATION_ASSIGN)
        mutex.destroy()
    }

    func _sourceForKeyPath(keyPath: String) -> Source<AnyObject> {
        return mutex.withLock {
            if let signal = self.signals[keyPath] {
                return signal.value.source
            }
            else {
                let signal = Signal<AnyObject>(
                    start: { signal in self.startObservingKeyPath(keyPath, signal: signal) },
                    stop: { signal in self.stopObservingKeyPath(keyPath) })
                // Note that signal now holds strong references to this KVOObserver
                self.signals[keyPath] = UnownedReference(signal)
                return signal.source
            }
        }
    }

    private func startObservingKeyPath(keyPath: String, signal: Signal<AnyObject>) {
        mutex.withLock {
            self.signals[keyPath] = UnownedReference(signal)
            self.object.addObserver(self, forKeyPath: keyPath, options: .New, context: &self.observerContext)
        }
    }

    private func stopObservingKeyPath(keyPath: String) {
        mutex.withLock {
            self.signals[keyPath] = nil
            self.object.removeObserver(self, forKeyPath: keyPath, context: &self.observerContext)
        }
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == &observerContext {
            if let keyPath = keyPath, change = change, newValue = change[NSKeyValueChangeNewKey] {
                if let signal = mutex.withLock({ self.signals[keyPath]?.value }) {
                    signal.send(newValue)
                }
            }
            else {
                fatalError("Unexpected KVO callback with key path '\(keyPath)'")
            }
        }
        else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
}

