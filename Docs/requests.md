# Requests

Resources start out empty — no data, no error, not loading. To trigger a GET request:

```swift
MyAPI.profile.loadIfNeeded()
```

Don’t worry about calling [`loadIfNeeded()`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#//apple_ref/swift/Method/loadIfNeeded()) too often. Call it in your `viewWillAppear()`! Call it in response to touch events! Call it 50 times a second! It automatically suppresses redundant requests. (Data expiration time is [configurable](configuration.md).)

To force a (possibly redundant) network request, use [`load()`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#//apple_ref/swift/Method/load()):

```swift
MyAPI.profile.load()
```

To mark the resource’s state dirty but defer the load until the next call to `loadIfNeeded()`, use [`invalidate()`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#//apple_ref/swift/Method/invalidate()):

```swift
MyAPI.profile.invalidate()
```

To update a resource with a POST/PUT/PATCH, use `request()`:

```swift
MyAPI.profile.request(.post, json: ["foo": [1,2,3]])
MyAPI.profile.request(.post, urlEncoded: ["foo": "bar"])
MyAPI.profile.request(.post, text: "Many years later, in front of the terminal...")
MyAPI.profile.request(.post, data: rawData, contentType: "text/limerick")
```

## Request Hooks

Siesta’s important distinguishing feature is that **observers** receive ongoing notifications about _all_ changes to a resource, no matter who initiated the change or when it arrived.

However, you can also attach **hooks** to an individual request, in the manner of more familiar HTTP frameworks:

```swift
resource.load()
    .onSuccess { data in print("Wow! Data!") }
    .onFailure { error in print("Oh, bummer.") }
```

These hooks are one-offs, called at most once when a specific request completes. They are appropriate when you care about the result of _a particular request_ instead of _a resource’s state in general._ This is usually what you want for a POST/PUT/PATCH; it is also sometimes appropriate for a user-initiated GET, e.g. when showing a spinner for a manually initiated refresh.

Though they are a less headline-grabbing feature of Siesta, these request hooks are quite robust. They have several advantages over similar hooks in other lower-level frameworks:

- They parse responses only once, instead of repeatedly for each callback.
- The `onFailure` callback reports client-side encoding and parsing errors through the same mechanism as server errors, so there is only a single error handling path to think about.
- The `onSuccess` callback magically provides actual data for a 304 (without any redundant deserializing or parsing!), so you don’t have to handle it as a special case in your app’s code.

Requests include a variety of useful callbacks, including an `onProgress` that knocks the pants off of the lurchy, freezy progress reporting you get from a network library out of the box.

See [`Request`](https://bustoutsolutions.github.io/siesta/api/Protocols/Request.html) for details.

## Request vs. Load

The `load()` and `loadIfNeeded()` methods update the resource’s state and notify observers when they receive a response. The various forms of the `request()` method, however, do not; it is up to you to say what effect if any your request had on the resource’s state.

Why? When you call `load()`, which is by default a GET request, you expect the server to return the full state of the resource. Siesta will cache that state and tell the world to display it.

When you call `request()`, however, you don’t necessarily expect the server to give you the full resource back. You might be making a POST request, for example, and the server may return only the relevant slice of resource state, even a simple “OK” in the form of a 204 with an empty response body.

In this situation, it’s up to you to update the local resource state. There are three ways to do this:

### Refresh After Update

One way to handle this is to trigger a load on the heels of a successful POST/PUT/PATCH:

```swift
resource.request(.put, json: newState).onSuccess() {
    _ in resource.load()
}
```

…or perhaps a POST request gives you the location of a new resource in a header:

```swift
resource.request(.post, json: newState).onSuccess() {
    let createdResource = resource.optionalRelative(
        $0.header(forKey: "Location"))
    …
}
```

### Local Mutation After Update

You can also manually update the local state using [`Resource.overrideLocalData(with:)`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#//apple_ref/swift/Method/overrideLocalData(with:)) or [`Resource.overrideLocalContent(with:)`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#//apple_ref/swift/Method/overrideLocalContent(with:)):

```swift
resource.request(.put, json: newState).onSuccess() {
    _ in resource.overrideLocalContent(with: newState)
}
```

…or perhaps you are making a partial update:

```swift
resource.request(.patch, json: ["foo": "bar"]).onSuccess() { _ in
    var updatedState = resource.jsonDict
    updatedState["foo"] = "bar"
    resource.overrideLocalContent(with: updatedState)
}
```

This technique avoids an extra network request, but it is dangerous: it puts the onus of keeping local state and server state entirely on you. Use with caution.

### Promoting a Request to be a Load

When a POST/PUT/PATCH response returns the entire state of the resource in exactly the same format as GET does, you can tell Siesta to treat it as a load request. Pass your manually created request directly to [`load(using:)`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#//apple_ref/swift/Method/load(using:)):

```swift
resource.load(using:
    resource.request(.put, json: newState)
        .onSuccess() { … })
```
