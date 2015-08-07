# Services and Resources

Services and resources are your entry point for interaction with Siesta. Together, they represent an API and the many RESTful resources within it.

## Services

A service represents an API, that is, a set of related RESTful resources which tend to share common rules about response structure, authentication, and other conventions.

You’ll typically create a `Service` singleton for each API your app uses:

```swift
let myAPI = Service(base: "https://api.example.com")  // top level
```

You don’t necessarily need to make it a singleton, but don’t just instantiate `Service` willy-nilly. Make sure there’s one instance that all the interested parties share. Much of the benefit of Siesta comes from the fact that all code using the same RESTful resource receives the same notifications. That happens within the context of one `Service` instance.

You can subclass `Service` to provide custom configuration in the initializer:

```swift
class MyAPI: Service {
  init() {
    super.init(base: "https://api.example.com")

    defaultExpirationTime = 10  // seconds before data considered stale
    responseTransformers.add(MyAPISpecialFancyErrorMessageExtractor())
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

  var profile: Resource {
    return resource("profile")
  }
  var items: Resource {
    return resource("items")
  }
  func item(id: String) -> Resource {
    return resource("items").child(id)
  }
}

let myAPI = MyAPI()
```

## Resources

A `Resource` is a local cache of a RESTful resource. It holds a representation of the the resource’s data, plus information about the status of network requests related to it.

This class answers three basic questions about a resource:

* What is the latest data for the resource we have, if any?
* Did the last attempt to load it result in an error?
* Is there a request in progress?

Retrieve resources from a service by providing paths relative to the service’s base URL:

```swift
myAPI.resource("/profile")
myAPI.resource("/items/123")
```

The leading slashes are optional, but help clarify.

You can navigate from a resource to a related resources:

```swift
// The following all return the same resource:

myAPI.resource("/items/123/detail")
myAPI.resource("/items").child("123").child("detail")
myAPI.resource("/items").child("123/detail")

myAPI.resource("/items").relative("./123/detail")
myAPI.resource("/items/456").relative("../123/detail")
myAPI.resource("/doodads").relative("/items/123/detail")
```

Within the context of a `Service`, there is at most one `Resource` object for a given URL, no matter how you navigate to it.
