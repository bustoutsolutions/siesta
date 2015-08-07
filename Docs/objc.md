# Using Siesta from Objective-C

Siesta follows a Swift-first design approach. It uses the full expressiveness of the language to make everything feel “Swift native,” both in interface and implementation.

However, a design constraint of Siesta is that **you can use it in your Objective-C app**. To that end, the features you’ll need to use in your app code are exposed in an Objective-C compatibility layer. Some features related to configuring and customizing Siesta’s behavior for a particular API are only available in Swift.

## What’s In, What’s Out

Features exposed to Objective-C:

 * Resource path navigation (child, relative, etc.)
 * Resource state
 * Observers
 * Request / load methods
 * Request completion callbacks
 * UI components

Some things are not exposed in the compatibility layer, and must be done in Swift:

 * Subclassing Service
 * Custom ResponseTransformers
 * Custom TransportProviders
 * Logging config

## Naming Conventions

In Swift, everything is namespaced to the framework (`Service` is shorthand for `Siesta.Service`). In Objective-C, however, classes and protocol use the `BOS` prefix to avoid namespace collisions:

 * BOSService
 * BOSRequest
 * BOSResourceData
 * BOSResourceError
 * BOSResourceObserver

Siesta structs are exposed as Objective-C classes. This incurs a _very_ slight performance overhead, which will not be a problem 99.9% of the time — but if for some reason you need to iterate over a massive number of resources and examine their `latestData`, it might be better to write that bit of code in Swift. Benchmark it and find out.

## Setting Up Services

Your `Service` subclass must be written in Swift. You can use it from both Objective-C and Swift code, however.

Objective-C can’t see Swift globals, so you’ll instead need to make your singleton a static constant:

```swift
class MyAPI: Service {
    let instance = MyAPI(base: "https://api.example.com")  // top level
}
```

You can then do:

```objc
[[MyAPI.instance resource:@"/profile"] child:@"123"];
```

## Observers

Siesta does not support the closure flavor of `addObserver` in Objective-C. You must implement the `BOSResourceObserver` protocol to observe resources.

Objective-C cannot see Swift enums, and `ResourceEvent` is an enum. Objective-C methods that deal with events take strings instead:

```objc
-  (void) resourceChanged: (BOSResource*) resource event: (NSString*) event {
  if([event isEqual:@"NewData"]) {
    ...
  }
}
```

## Request Callbacks

Most of the request callbacks translate naturally into Objective-C blocks, but the `completion` callback — which can receive either data on success or an error on failure — has a different flavor in Objective-C:

@property (nonatomic, readonly, copy) BOSRequest * __nonnull (^ __nonnull completion)(void (^ __nonnull)(BOSResourceData * __nullable, BOSResourceError * __nullable));
