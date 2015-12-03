# GlueKit
Yet another Swift framework for discrete reactive-style programming. There are many frameworks like it, but this one is mine! 

It is called GlueKit because it lets you stick stuff together.

Similar frameworks are 
[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa), 
[RxSwift](https://github.com/ReactiveX/RxSwift), 
[ReactKit](https://github.com/ReactKit/ReactKit),
[Interstellar](https://github.com/JensRavens/Interstellar), and a million others.

GlueKit provides some of the same constructs as these frameworks. Sometimes I even use the same names for things. Not often, though!

I have several reasons I wanted to create GlueKit instead of just using a better established and bug-free library:

- I wanted to have some experience with reactive stuff, and you can learn a lot about a paradigm by trying to construct its foundations on your own. The idea is that I start simple and add things as I find I need them. I want to see if I arrive at the same problems and solutions as the Smart People who created the popular frameworks. Some common reactive patterns are not obviously right at first glance.
- I wanted to experiment with reentrant observables, where an observer is allowed to trigger updates to the observable to which it's connected. I found no well-known implementation of Observable that gets this *just right*.
- Building a library is a really fun diversion!

