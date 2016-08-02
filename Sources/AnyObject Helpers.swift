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

public extension SourceType where SourceValue == AnyObject? {
    /// Casts all values to Type using an unsafe cast. Signals a fatal error if a value isn't a Type.
    func forceCasted<Type: AnyObject>() -> Source<Type> {
        return sourceOperator { value, sink in
            sink.receive(value as! Type)
        }
    }

    /// Casts all values to String via NSString. Signals a fatal error if a value isn't an NSString.
    var asString: Source<String> {
        return sourceOperator { value, sink in
            sink.receive(value as! String)
        }
    }

    /// Converts all values to Bool using NSNumber.integerValue. Signals a fatal error if a value isn't an NSNumber.
    var asBool: Source<Bool> {
        return sourceOperator { value, sink in
            let v = value as! NSNumber
            sink.receive(v.boolValue)
        }
    }

    /// Converts all values to Int using NSNumber.integerValue. Signals a fatal error if a value isn't an NSNumber.
    var asInt: Source<Int> {
        return sourceOperator { value, sink in
            let v = value as! NSNumber
            sink.receive(v.intValue)
        }
    }

    /// Converts all values to Float using NSNumber.floatValue. Signals a fatal error if a value isn't an NSNumber.
    var asFloat: Source<Float> {
        return sourceOperator { value, sink in
            let v = value as! NSNumber
            sink.receive(v.floatValue)
        }
    }

    /// Converts all values to Double using NSNumber.doubleValue. Signals a fatal error if a value isn't an NSNumber.
    var asDouble: Source<Double> {
        return sourceOperator { value, sink in
            let v = value as! NSNumber
            sink.receive(v.doubleValue)
        }
    }

    /// Converts all values to CGFloat using NSNumber.doubleValue. Signals a fatal error if a value isn't an NSNumber.
    var asCGFloat: Source<CGFloat> {
        return sourceOperator { value, sink in
            let v = value as! NSNumber
            sink.receive(CGFloat(v.doubleValue))
        }
    }

    #if !os(OSX) // It seems these conversions aren't predefined in the OS X SDK.
    /// Converts all values to CGPoint using NSValue.CGPointValue. Signals a fatal error if a value isn't an NSValue.
    var asCGPoint: Source<CGPoint> {
        return sourceOperator { value, sink in
            let v = value as! NSValue
            sink.receive(v.cgPointValue)
        }
    }

    /// Converts all values to CGSize using NSValue.CGSizeValue. Signals a fatal error if a value isn't an NSValue.
    var asCGSize: Source<CGSize> {
        return sourceOperator { value, sink in
            let v = value as! NSValue
            sink.receive(v.cgSizeValue)
        }
    }

    /// Converts all values to CGRect using NSValue.CGRectValue. Signals a fatal error if a value isn't an NSValue.
    var asCGRect: Source<CGRect> {
        return sourceOperator { value, sink in
            let v = value as! NSValue
            sink.receive(v.cgRectValue)
        }
    }

    /// Converts all values to CGAffineTransformValue using NSValue.CGAffineTransformValue.  Signals a fatal error if a value isn't an NSValue.
    var asCGAffineTransform: Source<CGAffineTransform> {
        return sourceOperator { value, sink in
            let v = value as! NSValue
            sink.receive(v.cgAffineTransformValue)
        }
    }
    #endif
}

public extension ObservableType where Value == AnyObject? {
    /// Casts all values to Type using an unsafe cast. Signals a fatal error if a value isn't a Type.
    func forceCasted<Type: AnyObject>() -> Observable<Type> {
        return self.map { $0 as! Type }
    }

    /// Casts all values to String via NSString. Signals a fatal error if a value isn't an NSString.
    var asString: Observable<String> {
        return self.map { $0 as! String }
    }

    /// Converts all values to Bool using NSNumber.integerValue. Signals a fatal error if a value isn't an NSNumber.
    var asBool: Observable<Bool> {
        return self.map {
            let v = $0 as! NSNumber
            return v.boolValue
        }
    }

    /// Converts all values to Int using NSNumber.integerValue. Signals a fatal error if a value isn't an NSNumber.
    var asInt: Observable<Int> {
        return self.map {
            let v = $0 as! NSNumber
            return v.intValue
        }
    }

    /// Converts all values to Float using NSNumber.floatValue. Signals a fatal error if a value isn't an NSNumber.
    var asFloat: Observable<Float> {
        return self.map {
            let v = $0 as! NSNumber
            return v.floatValue
        }
    }

    /// Converts all values to Double using NSNumber.doubleValue. Signals a fatal error if a value isn't an NSNumber.
    var asDouble: Observable<Double> {
        return self.map {
            let v = $0 as! NSNumber
            return v.doubleValue
        }
    }

    /// Converts all values to CGFloat using NSNumber.doubleValue. Signals a fatal error if a value isn't an NSNumber.
    var asCGFloat: Observable<CGFloat> {
        return self.map {
            let v = $0 as! NSNumber
            return CGFloat(v.doubleValue)
        }
    }

    #if !os(OSX) // It seems these conversions aren't predefined in the OS X SDK.
    /// Converts all values to CGPoint using NSValue.CGPointValue. Signals a fatal error if a value isn't an NSValue.
    var asCGPoint: Observable<CGPoint> {
        return self.map {
            let v = $0 as! NSValue
            return v.cgPointValue
        }
    }

    /// Converts all values to CGSize using NSValue.CGSizeValue. Signals a fatal error if a value isn't an NSValue.
    var asCGSize: Observable<CGSize> {
        return self.map {
            let v = $0 as! NSValue
            return v.cgSizeValue
        }
    }

    /// Converts all values to CGRect using NSValue.CGRectValue. Signals a fatal error if a value isn't an NSValue.
    var asCGRect: Observable<CGRect> {
        return self.map {
            let v = $0 as! NSValue
            return v.cgRectValue
        }
    }

    /// Converts all values to CGAffineTransformValue using NSValue.CGAffineTransformValue.  Signals a fatal error if a value isn't an NSValue.
    var asCGAffineTransform: Observable<CGAffineTransform> {
        return self.map {
            let v = $0 as! NSValue
            return v.cgAffineTransformValue
        }
    }
    #endif
}
