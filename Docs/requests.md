# Requests

Resources start out empty — no data, no error, not loading. To trigger a GET request:

```swift
MyAPI.profile.loadIfNeeded()
```

Don’t worry about calling [`loadIfNeeded()`](http://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#/s:FC6Siesta8Resource12loadIfNeededFS0_FT_GSqPS_7Request__) too often. Call it in your `viewWillAppear()`! Call it in response to touch events! Call it 50 times a second! It automatically suppresses redundant requests. (Data expiration time is [configurable](configuration.md).)

To force a (possibly redundant) network request, use [`load()`](http://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#/s:FC6Siesta8Resource4loadFS0_FT_PS_7Request_):

```swift
MyAPI.profile.load()
```

To mark the resource’s state dirty but defer the load until the next call to `loadIfNeeded()`, use [`invalidate()`](http://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#/s:FC6Siesta8Resource10invalidateFS0_FT_T_):

```swift
MyAPI.profile.invalidate()
```

To update a resource with a POST/PUT/PATCH, use `request()`:

```swift
MyAPI.profile.request(.POST, json: ["foo": [1,2,3]])
MyAPI.profile.request(.POST, urlEncoded: ["foo": "bar"])
MyAPI.profile.request(.POST, text: "Many years later, in front of the terminal...")
MyAPI.profile.request(.POST, data: nsdata)
```

## Request Hooks

Siesta’s important distinguishing feature is that **observers** receive ongoing notifications about _all_ changes to a resource, no matter who initiated the change or when it arrived.

However, you can also attach **hooks** to an individual request, in the manner of more familiar HTTP frameworks:

```swift
resource.load()
    .success { data in print("Wow! Data!") }
    .failure { error in print("Oh, bummer.") }
```

These hooks are one-offs, called at most once when a specific request completes.

Though they are a secondary feature, these request hooks are quite robust. They have several advantages over similar hooks in other lower-level frameworks. For example, they parse responses only once (instead of repeatedly for each callback), the `failure` callback captures response deserializing errors as well as server errors, and the success callback provides actual data for a 304 (without deserializing again!).

See [`Request`](http://bustoutsolutions.github.io/siesta/api/Protocols/Request.html) for details.

## Request vs. Load

The `load()` and `loadIfNeeded()` methods update the resource’s state and notify observers when they receive a response. The various forms of the `request()` method, however, do not; it is up to you to say what effect if any your request had on the resource’s state.

When you call `load()`, which is by default a GET request, you expect the server to return the full state of the resource. Siesta will cache that state and tell the world to display it.

When you call `request()`, however, you don’t necessarily expect the server to give you the full resource back. You might be making a POST request, and the server will simply say “OK” — perhaps by returning 201 or 204 with an empty response body. In this situation, it’s up to you to update the resource state.

One way to do this is to trigger a load on the heels of a successful POST/PUT/PATCH:

```swift
resource.request(.PUT, json: newState).success() {
    _ in resource.load()
}
```

…or perhaps a POST request gives you the location of a new resource in a header:

```swift
resource.request(.POST, json: newState).success() {
    let createdResource = resource.relative($0.header("Location")))
    …
}
```

You can also pass a custom request directly to [`load(usingRequest:)`](http://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#/s:FC6Siesta8Resource4loadFS0_FT12usingRequestPS_7Request__PS1__).