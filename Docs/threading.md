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

  - [`Service`](http://bustoutsolutions.github.io/siesta/api/Classes/Service.html)
  - [`Resource`](http://bustoutsolutions.github.io/siesta/api/Classes/Resource.html)
  - [`Request`](http://bustoutsolutions.github.io/siesta/api/Protocols/Request.html)

In development builds, internal Siesta assertions will flag most violations of this rule.

Because they are likely to update the UI, Siesta calls the following user-provided callbacks on the main thread:

  - [`ResourceObserver`](http://bustoutsolutions.github.io/siesta/api/Protocols/ResourceObserver.html) methods and
  - [`Request`](http://bustoutsolutions.github.io/siesta/api/Protocols/Request.html) hooks.

It is your responsibility to ensure that your callbacks do not block the main thread for excessive amounts of time.

## Background Queue Operations

Because they may involve parsing and transformation of large amounts of data, Siesta performs these two tasks on GCD background queues:

  - response parsing and
  - entity caching.

You thus must ensure that your implementations of the following protocols are threadsafe:

  - [`ResponseTransformer`](http://bustoutsolutions.github.io/siesta/api/Protocols/ResponseTransformer.html)
  - [`EntityCache`](http://bustoutsolutions.github.io/siesta/api/Protocols/EntityCache.html)
  - [`EntityEncoder`](http://bustoutsolutions.github.io/siesta/api/Protocols/EntityEncoder.html)

These interfaces pass only structs as input and output, so you will typically not need to synchronize access to Siesta’s state. However, you will need to be careful about using shared resources, such as a cache’s data store. Also take care if you work with entities whose [`content`](http://bustoutsolutions.github.io/siesta/api/Structs/Entity.html#/s:vV6Siesta6Entity7contentP_) is a mutable object and not a struct.

## Networking and Threading

Most networking libraries use threads internally (including `NSURLSession`, Siesta’s default). Siesta therefore delegates threading responsibility to the networking provider. If you write a custom [`NetworkingProvider`](http://bustoutsolutions.github.io/siesta/api/Protocols/NetworkingProvider.html) implementation, you thus must exercise a little care about threading.

Siesta will always call your [`startRequest()`](http://bustoutsolutions.github.io/siesta/api/Protocols/NetworkingProvider.html#/s:FP6Siesta18NetworkingProvider12startRequestuRq_S0__Fq_FTCSo12NSURLRequest10completionFT5nsresGSqCSo17NSHTTPURLResponse_4bodyGSqCSo6NSData_5errorGSqPSs9ErrorType___T__PS_17RequestNetworking_) on the main thread, but it _is_ safe to call the `completion` callback from a background thread without any synchronization.

It is your responsibility to ensure that any code that queries or alters the state of a request in progress does so in a threadsafe manner. This includes the members of [`RequestNetworking`](http://bustoutsolutions.github.io/siesta/api/Protocols/RequestNetworking.html). (Most networking libraries already provide the necessary thread safety, and you won’t need to take any thread safety measures yourself. Just make sure that this is indeed the case!)
