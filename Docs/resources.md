# Services and Resources

## Services

A service represents an API, that is, a set of related RESTful resources which tend to share common rules about response format, authentication, etc.

You’ll typically create a `Service` singleton for each API your app uses:

```swift
let myAPI = Service(base: "https://api.example.com")  // top level
```

Don’t keep instantiating `Service`; whether singleton or not, make sure there’s one instance that all the interested parties share.

You can subclass `Service` to provide custom configuration in the initializer:

```swift
class MyAPI: Service {
  init() {
    super.init(base: "https://api.example.com")
    defaultExpirationTime = 10  // seconds before data considered stale
  }
}

let myAPI = MyAPI()
```

You may also want to add convenience accessors for commonly used resources:

```swift
class MyAPI: Service {
  init() {
    super.init(base: "https://api.example.com")
  }

  var profile: Resource { return resource("profile") }
  var items: Resource { return resource("items") }
  func items(id: String) -> Resource { return resource("items").child(id) }
}

let myAPI = MyAPI()
```

## Resources

Resources are your primary point of interaction with Siesta. A `Resource` is a local cache of a RESTful resource. It hold a representation of the the resource’s data, plus information about the status of any network requests related to it.

This class answers three basic questions about a resource:

* What is the latest data for the resource this device has retrieved, if any?
* Did the last attempt to load it result in an error?
* Is there a request in progress?

Retrieve resources from a service by providing paths relative to the service’s base URL:

```swift
myAPI.resource("/profile")
myAPI.resource("/items/123")
```

The leading slashes are optional, but help clarify.

```swift
myAPI.resource("/items").child("123").child("detail")
myAPI.resource("/items/123/detail") // same as previous
```

Within the context of a `Service`, there is at most one `Resource` object for a given URL, no matter how you navigate to that URL.

## From Objective-C

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
