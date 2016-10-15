# Services and Resources

Services and resources are the heart of Siesta.

## Services

A [`Service`](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html) represents an API, that is, a set of related resources which tend to share common rules about request and response structure, authentication, and other conventions.

Create a single `Service` instance for each API your app uses:

```swift
let myAPI = Service(baseURL: "https://api.example.com")  // global var
```

You don’t necessarily need to make it a singleton as in this example, but don’t just instantiate `Service` willy-nilly. Make sure there’s one instance that all the interested parties share. Much of the benefit of Siesta comes from the fact that all code using the same RESTful resource is working with the same object, and receives the same notifications. That happens within the context of one `Service` instance.

Although it’s not strictly necessary, it can be pleasant to subclass `Service` to add convenience accessors for commonly used resources:

```swift
class MyAPI: Service {
  init() {
    super.init(baseURL: "https://api.example.com")
  }

  var profile: Resource { return resource("/profile") }
  var items:   Resource { return resource("/items") }

  func item(id: String) -> Resource {
    return items.child(id)
  }
}

let myAPI = MyAPI()
```

Note the use of computed properties instead of read-only (`let`) properties. This lets the service discard resources not currently in use if memory gets low.

## Getting Resources

A [`Resource`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html) is a local cache of a RESTful resource. It holds a representation of the the resource’s data, plus information about the status of network requests related to it.

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
myAPI.resource("/items/456").relative("./123/detail")
myAPI.resource("/items/456/detail").relative("../123/detail")
myAPI.resource("/doodads/etc").relative("/items/123/detail")
```

The `child(_:)` method appends path components, while `relative(_:)` uses full relative URL resolution rules (like `href` in a web page).

For more details, see the API docs for [`child(_:)`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#//apple_ref/swift/Method/child(_:)) and [`relative(_:)`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#//apple_ref/swift/Method/relative(_:)), and the [related specs](https://bustoutsolutions.github.io/siesta/specs/#ResourcePathsSpec).

## The Golden Rule of Resources

> Within the context of a `Service` instance, at any given time there is at most one `Resource` object for a given URL.

This is true no matter how you navigate to a resource, no matter whether you retain it or re-request it, no matter what — just as long as the resource came (directly or indirectly) from the same `Service` instance.

### Ephemerality

Note that the rule is “at _most_ one.” If memory is low and no code references a particular resource, a service may choose to discard it and recreate it later if needed. This is transparent to client code; as long as you retain a reference to a resource, you will always keep getting only that reference. However, it does mean that resource objects are ephemeral, created and recreated on demand.

### Uniqueness

Note that “URL” includes the _whole_ URL: protocol, host, path, and query string. It does _not_ include headers, however. Different query strings? Different resources. `http` vs `https`? Different resources. Different `Authentication` headers? _Same_ resource. This means it’s up to you to [wipe resource content](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html#//apple_ref/swift/Method/wipeResources(matching:)) when a user logs out.
