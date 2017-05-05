
# Overview of GlueKit

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [Sources, Sinks and Connections](#sources-sinks-and-connections)
- [Signals](#signals)
- [Observables, Updatables and Variable](#observables-updatables-and-variable)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Sources, Sinks and Connections

In GlueKit, the `SourceType` protocol models a thing that you can subscribe to receive a stream of values. 

```Swift
protocol SourceType {
    typealias Value
    func subscribe(sink: Value->Void) -> Connection
}
```

It is not easy to work with associated types, so GlueKit generally uses the struct `Source<Value>` to represent sources. `Source<Value>` is a type-erased wrapper around some `SourceType` for the same type of value.

For example, you can create a source for the `NSCalendarDayChangedNotification` notification
and run some code whenever midnight passes:

```Swift
let center = NSNotificationCenter.defaultCenter()
let midnightSource = center.source(forName: NSCalendarDayChangedNotification)

let connection = midnightSource.subscribe { notification in 
    print("Ding dong!") 
}
```

The subscription (and the source) is kept alive until the connection object is deinitalized
or until its `disconnect` method is called. Thus, active connections hold strong
references to their source and sink---this is a general rule in GlueKit.

There is a `Connector` class that is a convenient place to store connections that you need to keep
alive without creating a property for each individual connection:

```Swift
class ClockViewController: UIViewController {
    private connectionsWhileVisible = Connector()
    
    // TimerSource is a source that periodically broadcasts a Void value as long as it is connected.
    private let tickSource = TimerSource(start: NSDate(), interval: 1.0)

    private var midnightSource: Source<NSNotification> {
        let center = NSNotificationCenter.defaultCenter()
		return center.source(forName: NSCalendarDayChangedNotification)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        tickSource.subscribe(self.onTick).putInto(connectionsWhileVisible)
        midnightSource.subscribe { _ in self.onMidnight() }.putInto(connectionsWhileVisible)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        connectionsWhileVisible.disconnect()
    }
    
    func onTick() {
        print("Tick!")
    }
    
    func onMidnight() {
        print("Ding dong!")
    }
}
```

## Signals

The `Signal` class lets you easily create your own sources. 
It implements `SourceType`, keeps track of its connections, and provides a `send` method for you to send values to all its connected sinks:

```Swift
let signal = Signal<Int>()

signal.send(42) // Does nothing, no subscribers

let connection = signal.subscribe { i in print("Got \(i\)!") }

signal.send(23) // Prints "Got 23!"
signal.send(7)  // Prints "Got 7!"

connection.disconnect()
```

For example, a button's implementation might have a Void-valued signal that triggers whenever the user
taps on it. In such cases, it's best to not let outside code send values to the signal, so the 
`Signal` instance is frequently stored in a private property and the class exposes only a 
"read-only" source view of it:

```Swift
class Button: UIButton {
    private let activationSignal: Signal<Void>()
    public var activationSource: Source<Void> { return activationSignal.source }
    
	init() {
	    super.init(...)
	    addTarget(self, action: "didTouchUpInside", forControlEvents: UIControlEventTouchUpInside)
	}
    
    @objc func didTouchUpInside() {
        activationSignal.send()
    }
}
```

This is the way most sources are implemented in GlueKit.

## Observables, Updatables and Variable

A concrete implementation of this protocol is the generic class `Variable`, which directly holds such a value. 

Let's create a class with an observable property.

```Swift
class Person {
    let name: Variable<String>
    init(name: String) { self.name.value = name }
}

let fred = Person(name: "Fred")

// The variable's value property let's you get Fred's name or update it:
print(fred.name.value)         
fred.name.value = "Freddie"
```

`let foo: Variable<Type>` is the GlueKit equivalent to Cocoa's `dynamic var foo: Type`.

Once you have an observable value, you can start observing it:

```Swift

let connection = fred.name.subscribe { name in print("Fred's name is \(name)") }
```

This will immediately print `Fred's name is Fred` to the console, because by default variables 
send their current values to each new observer. If you don't want this, you can subscribe to the
variable's `futureValues` property instead.

