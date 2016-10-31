# Threading

Siesta maintains a simple thread model.

All operations involving **shared state**:

  - happen on the main thread, and
  - return very quickly (nanoseconds) for typical use.

All operations expected to be **time-intensive**:

  - use only structs (i.e. non-shared data) for their input and output, and
  - run on GCD background queues.

## Main Queue Operations

The vast majority of Siesta’s API surface falls into that “quick return, main thread only” category. This means that you **must** call all methods of all the following types from the main thread:

  - [`Service`](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html)
  - [`Resource`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html)
  - [`Request`](https://bustoutsolutions.github.io/siesta/api/Protocols/Request.html)

In development builds, internal Siesta assertions will flag most violations of this rule.

Because they are likely to update the UI, Siesta calls the following user-provided callbacks on the main thread:

  - [`ResourceObserver`](https://bustoutsolutions.github.io/siesta/api/Protocols/ResourceObserver.html) methods and
  - [`Request`](https://bustoutsolutions.github.io/siesta/api/Protocols/Request.html) hooks.

It is your responsibility to ensure that your callbacks do not block the main thread for excessive amounts of time.

## Background Queue Operations

Because they may involve parsing and transformation of large amounts of data, Siesta performs these two tasks on GCD background queues:

  - response parsing and
  - entity caching.

You thus must ensure that the following are threadsafe:

  - closures you pass to [configureTransformer](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html#//apple_ref/swift/Method/configureTransformer(_:requestMethods:atStage:action:onInputTypeMismatch:transformErrors:description:contentTransform:)) and [`ResponseContentTransformer`](https://bustoutsolutions.github.io/siesta/api/Structs/ResponseContentTransformer.html),
  - implementations of [`ResponseTransformer`](https://bustoutsolutions.github.io/siesta/api/Protocols/ResponseTransformer.html), and
  - implementations of [`EntityCache`](https://bustoutsolutions.github.io/siesta/api/Protocols/EntityCache.html).

All of these pass only structs as input and output, so you will typically not need to do any synchronization dances with them. However, you will need to be careful about using shared resources, such as a cache’s data store. Also take care if you work with entities whose [`content`](https://bustoutsolutions.github.io/siesta/api/Structs/Entity.html#//apple_ref/swift/Property/content) is a mutable object and not a struct.

## Networking and Threading

This section is only of concern if you are writing a custom networking provider.

Most networking libraries use threads internally (including `URLSession`, Siesta’s default). Siesta therefore delegates threading responsibility to the networking provider. If you write a custom [`NetworkingProvider`](https://bustoutsolutions.github.io/siesta/api/Protocols/NetworkingProvider.html) implementation, you thus must exercise a little care about threading.

Siesta will always call your [`startRequest()`](https://bustoutsolutions.github.io/siesta/api/Protocols/NetworkingProvider.html#//apple_ref/swift/Method/startRequest(_:completion:)) on the main thread, but it _is_ safe to call the `completion` callback from a background thread without any synchronization.

It is your responsibility to ensure that any code that queries or alters the state of a request in progress does so in a threadsafe manner. This includes the members of [`RequestNetworking`](https://bustoutsolutions.github.io/siesta/api/Protocols/RequestNetworking.html). (Most networking libraries already provide the necessary thread safety, and you won’t need to take any thread safety measures yourself. Just make sure that this is indeed the case!)
