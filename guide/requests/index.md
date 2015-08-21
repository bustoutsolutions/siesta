---
title: 'Requests'
layout: default
---

# Requests

Resources start out empty — no data, no error, not loading. To trigger a GET request:

```swift
MyAPI.profile.loadIfNeeded()
```

Don’t worry about calling [`loadIfNeeded()`](http://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#/s:FC6Siesta8Resource12loadIfNeededFS0_FT_GSqPS_7Request__) too often. Call it in your `viewWillAppear()`! Call it in response to touch events! Call it 50 times a second! It automatically suppresses redundant requests. (Data expiration time is configurable on a per-service and per-resource level.)

To force a network request, use [`load()`](http://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#/s:FC6Siesta8Resource4loadFS0_FT_PS_7Request_):

```swift
MyAPI.profile.load()
```

To update a resource with a POST/PUT/PATCH, use `request()`:

```swift
MyAPI.profile.request(.POST, json: ["foo": [1,2,3]])
MyAPI.profile.request(.POST, urlEncoded: ["foo": "bar"])
MyAPI.profile.request(.POST, text: "Many years later, in front of the terminal...")
MyAPI.profile.request(.POST, data: nsdata)
```

## Response Hooks

Siesta’s important distinguishing feature is that an _observer_ will keep receiving notifications about a resource, no matter who requests it, no matter when the responses arrive.

However, you can also attach callbacks to an individual request, in the manner of more familiar HTTP frameworks:

```swift
resource.load()
    .success { data in print("Wow! Data!") }
    .failure { error in print("Oh, bummer.") }
```

Though they are a secondary feature, these request hooks are quite robust (and better-behaved than similar hooks in some of the frameworks in which they are the primary feature). See [`Request`](http://bustoutsolutions.github.io/siesta/api/Protocols/Request.html) for details.

These _response callbacks_ are one-offs, called at most once when a request completes and then discarded.

## Request vs. Load

The `load()` and `loadIfNeeded()` methods update the resource’s state and notify observers when they receive a response. The various forms of the `request()` method, however, do not; it is up to you to say what effect if any your request had on the resource’s state.

When you call `load()`, which is by default a GET request, you expect the server to return the full state of the resource. Siesta will cache that state and tell the world to display it.

When you call `request()`, however, you don’t necessarily expect the server to give you the full resource back. You might be making a POST request, and the server will simply say “OK” — perhaps by returning 200 and an empty response body. In this situation, it’s up to you to update the resource state.

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

Next: **[Configuration](../configuration)**
{: .guide-next}
