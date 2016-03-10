//
//  AnyObject Helpers.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-03-10.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
    import UIKit // For NSValue.CGPointValue and similar conversions
#elseif os(watchOS)
    import WatchKit
#endif

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

    /// Converts all values to CGFloat using NSNumber.doubleValue. Signals a fatal error if a value isn't an NSNumber.
    func toCGFloat() -> Source<CGFloat> {
        return sourceOperator { value, sink in
            let v = value as! NSNumber
            sink.receive(CGFloat(v.doubleValue))
        }
    }

    #if !os(OSX) // It seems these conversion aren't predefined in the OS X SDK.
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
