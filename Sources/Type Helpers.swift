//
//  Type Helpers.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-03-10.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation
#if os(macOS)
    import AppKit
#elseif os(iOS) || os(tvOS)
    import UIKit // For NSValue.CGPointValue and similar conversions
#elseif os(watchOS)
    import WatchKit
#endif

private func toString(_ value: Any?) -> String {
    return value as! String
}
private func toBool(_ value: Any?) -> Bool {
    let v = value as! NSNumber
    return v.boolValue
}
private func toInt(_ value: Any?) -> Int {
    let v = value as! NSNumber
    return v.intValue
}
private func toFloat(_ value: Any?) -> Float {
    let v = value as! NSNumber
    return v.floatValue
}
private func toDouble(_ value: Any?) -> Double {
    let v = value as! NSNumber
    return v.doubleValue
}
private func toCGFloat(_ value: Any?) -> CGFloat {
    let v = value as! NSNumber
    return CGFloat(v.doubleValue)
}
private func toCGPoint(_ value: Any?) -> CGPoint {
    let v = value as! NSValue
    #if os(macOS)
        return v.pointValue
    #else
        return v.cgPointValue
    #endif
}
private func toCGSize(_ value: Any?) -> CGSize {
    let v = value as! NSValue
    #if os(macOS)
        return v.sizeValue
    #else
        return v.cgSizeValue
    #endif
}
private func toCGRect(_ value: Any?) -> CGRect {
    let v = value as! NSValue
    #if os(macOS)
        return v.rectValue
    #else
        return v.cgRectValue
    #endif
}
private let encodedCGAffineTransform = (CGFloat.NativeType.self == Double.self ? "{CGAffineTransform=dddddd}" : "{CGAffineTransform=ffffff}")
private func toCGAffineTransform(_ value: Any?) -> CGAffineTransform {
    let v = value as! NSValue
    #if os(macOS)
        precondition(String(cString: v.objCType) == encodedCGAffineTransform)
        var transform = CGAffineTransform.identity
        v.getValue(&transform)
        return transform
    #else
        return v.cgAffineTransformValue
    #endif
}

public extension SourceType where SourceValue == Any? {
    /// Casts all values to Type using an unsafe cast. Signals a fatal error if a value isn't a Type.
    func forceCasted<T: AnyObject>(to type: T.Type = T.self) -> Source<T> {
        return sourceOperator { value, sink in
            sink.receive(value as! T)
        }
    }

    /// Casts all values to String via NSString. Signals a fatal error if a value isn't an NSString.
    var asString: Source<String> { return map(toString) }

    /// Converts all values to Bool using NSNumber.boolValue. Signals a fatal error if a value isn't an NSNumber.
    var asBool: Source<Bool> { return map(toBool) }

    /// Converts all values to Int using NSNumber.integerValue. Signals a fatal error if a value isn't an NSNumber.
    var asInt: Source<Int> { return map(toInt) }

    /// Converts all values to Float using NSNumber.floatValue. Signals a fatal error if a value isn't an NSNumber.
    var asFloat: Source<Float> { return map(toFloat) }

    /// Converts all values to Double using NSNumber.doubleValue. Signals a fatal error if a value isn't an NSNumber.
    var asDouble: Source<Double> { return map(toDouble) }

    /// Converts all values to CGFloat using NSNumber.doubleValue. Signals a fatal error if a value isn't an NSNumber.
    var asCGFloat: Source<CGFloat> { return map(toCGFloat) }

    /// Converts all values to CGPoint using NSValue.CGPointValue. Signals a fatal error if a value isn't an NSValue.
    var asCGPoint: Source<CGPoint> { return map(toCGPoint) }

    /// Converts all values to CGSize using NSValue.CGSizeValue. Signals a fatal error if a value isn't an NSValue.
    var asCGSize: Source<CGSize> { return map(toCGSize) }

    /// Converts all values to CGRect using NSValue.CGRectValue. Signals a fatal error if a value isn't an NSValue.
    var asCGRect: Source<CGRect> { return map(toCGRect) }

    /// Converts all values to CGAffineTransformValue using NSValue.CGAffineTransformValue.  Signals a fatal error if a value isn't an NSValue.
    var asCGAffineTransform: Source<CGAffineTransform> { return map(toCGAffineTransform) }
}

public extension ObservableValueType where Value == Any? {
    /// Casts all values to Type using a forced cast. Traps if a value can't be casted to the specified type.
    func forceCasted<T: AnyObject>(to type: T.Type = T.self) -> Observable<T> {
        return self.map { $0 as! T }
    }

    /// Casts all values to String via NSString. Signals a fatal error if a value isn't an NSString.
    var asString: Observable<String> { return self.map(toString) }

    /// Converts all values to Bool using NSNumber.integerValue. Signals a fatal error if a value isn't an NSNumber.
    var asBool: Observable<Bool> { return self.map(toBool) }

    /// Converts all values to Int using NSNumber.integerValue. Signals a fatal error if a value isn't an NSNumber.
    var asInt: Observable<Int> { return self.map(toInt) }

    /// Converts all values to Float using NSNumber.floatValue. Signals a fatal error if a value isn't an NSNumber.
    var asFloat: Observable<Float> { return self.map(toFloat) }

    /// Converts all values to Double using NSNumber.doubleValue. Signals a fatal error if a value isn't an NSNumber.
    var asDouble: Observable<Double> { return self.map(toDouble) }

    /// Converts all values to CGFloat using NSNumber.doubleValue. Signals a fatal error if a value isn't an NSNumber.
    var asCGFloat: Observable<CGFloat> { return self.map(toCGFloat) }

    /// Converts all values to CGPoint using NSValue.CGPointValue. Signals a fatal error if a value isn't an NSValue.
    var asCGPoint: Observable<CGPoint> { return self.map(toCGPoint) }

    /// Converts all values to CGSize using NSValue.CGSizeValue. Signals a fatal error if a value isn't an NSValue.
    var asCGSize: Observable<CGSize> { return self.map(toCGSize) }

    /// Converts all values to CGRect using NSValue.CGRectValue. Signals a fatal error if a value isn't an NSValue.
    var asCGRect: Observable<CGRect> { return self.map(toCGRect) }

    /// Converts all values to CGAffineTransformValue using NSValue.CGAffineTransformValue.  Signals a fatal error if a value isn't an NSValue.
    var asCGAffineTransform: Observable<CGAffineTransform> { return self.map(toCGAffineTransform) }
}

public extension UpdatableValueType where Value == Any? {
    /// Casts all values to Type using a forced cast. Traps if a value can't be casted to the specified type.
    func forceCasted<T: AnyObject>(to type: T.Type = T.self) -> Updatable<T> {
        return self.map({ $0 as! T }, inverse: { $0 as Any? })
    }

    /// Casts all values to String via NSString. Signals a fatal error if a value isn't an NSString.
    var asString: Updatable<String> { return self.map(toString, inverse: { $0 }) }

    /// Converts all values to Bool using NSNumber.integerValue. Signals a fatal error if a value isn't an NSNumber.
    var asBool: Updatable<Bool> { return self.map(toBool, inverse: { NSNumber(value: $0) }) }

    /// Converts all values to Int using NSNumber.integerValue. Signals a fatal error if a value isn't an NSNumber.
    var asInt: Updatable<Int> { return self.map(toInt, inverse: { NSNumber(value: $0) }) }

    /// Converts all values to Float using NSNumber.floatValue. Signals a fatal error if a value isn't an NSNumber.
    var asFloat: Updatable<Float> { return self.map(toFloat, inverse: { NSNumber(value: $0) }) }

    /// Converts all values to Double using NSNumber.doubleValue. Signals a fatal error if a value isn't an NSNumber.
    var asDouble: Updatable<Double> { return self.map(toDouble, inverse: { NSNumber(value: $0) }) }

    /// Converts all values to CGFloat using NSNumber.doubleValue. Signals a fatal error if a value isn't an NSNumber.
    var asCGFloat: Updatable<CGFloat> { return self.map(toCGFloat, inverse: { NSNumber(value: Double($0)) }) }

    /// Converts all values to CGPoint using NSValue.CGPointValue. Signals a fatal error if a value isn't an NSValue.
    var asCGPoint: Updatable<CGPoint> {
        return self.map(toCGPoint, inverse: {
            #if os(macOS)
                return NSValue(point: $0)
            #else
                return NSValue(cgPoint: $0)
            #endif
        })
    }

    /// Converts all values to CGSize using NSValue.CGSizeValue. Signals a fatal error if a value isn't an NSValue.
    var asCGSize: Updatable<CGSize> {
        return self.map(toCGSize, inverse: {
            #if os(macOS)
                return NSValue(size: $0)
            #else
                return NSValue(cgSize: $0)
            #endif
        })
    }

    /// Converts all values to CGRect using NSValue.CGRectValue. Signals a fatal error if a value isn't an NSValue.
    var asCGRect: Updatable<CGRect> {
        return self.map(toCGRect, inverse: {
            #if os(macOS)
                return NSValue(rect: $0)
            #else
                return NSValue(cgRect: $0)
            #endif
        })
    }

    /// Converts all values to CGAffineTransformValue using NSValue.CGAffineTransformValue.  Signals a fatal error if a value isn't an NSValue.
    var asCGAffineTransform: Updatable<CGAffineTransform> {
        return self.map(toCGAffineTransform, inverse: {
            #if os(macOS)
                var transform = $0
                return NSValue(bytes: &transform, objCType: encodedCGAffineTransform)
            #else
                return NSValue(cgAffineTransform: $0)
            #endif
        })
    }
}
