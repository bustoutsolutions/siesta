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

 * Subclassing `Service`
 * Configuration
 * Custom `ResponseTransformer`s
 * Custom `NetworkingProvider`s
 * Logging config

## Naming Conventions

In Swift, everything is namespaced to the framework (`Service` is shorthand for `Siesta.Service`). In Objective-C, however, classes and protocol use the `BOS` prefix to avoid namespace collisions:

 * `BOSService`
 * `BOSRequest`
 * `BOSEntity`
 * `BOSError`
 * `BOSResourceObserver`

Siesta structs are exposed as Objective-C classes. This incurs a _very_ slight performance overhead, which will not be a problem 99.9% of the time — but if for some reason you need to iterate over a massive number of resources and examine their `latestData`, it _might_ be better to write that bit of code in Swift. Benchmark it and find out.

## Setting Up Services

You can use `Service` subclass from both Objective-C and Swift, but you must write it in Swift.

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

Objective-C cannot see Swift enums, and `ResourceEvent` is an enum. Objective-C methods that deal with events take strings instead:

```objc
-  (void) resourceChanged: (BOSResource*) resource event: (NSString*) event {
  if([event isEqual:@"NewData"]) {
    ...
  }
}
```

## Request Methods

Some things that would be compile errors in Swift’s more robust static type system surface as runtime errors in Objective-C.

Of particular note are the various flavors of `[Resource requestWithMethod:...]`, which take a string instead of an enum for the HTTP method. That means that what is a compile error in Swift:

```swift
resource.request(.FLARGLE)
```

…is a crash in Objective-C:

```objc
[resource.requestWithMethod:@"FLARGLE"]
```

## Request Callbacks

Most of the request callbacks translate naturally into Objective-C blocks, but the `completion` callback, which can receive either data on success or an error on failure:

```swift
resource.request(.POST, json: ["color": "green"])
    .completion { response in
        switch response {
            case .Success(let data):
                ...
            
            case .Failure(let error):
                ...
        }
    }
```

…has a different, less type-safe flavor in Objective-C:

```objc
[resource.requestWithMethod:@"POST" json:@{@"color": @"mauve"}]
    .completion:(^(BOSEntity *data, BOSError *error) {
        ...
    });
```

Exactly one of the completion block’s two arguments will be non-nil.
