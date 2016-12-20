# Transformer Pipeline

As part of its design goal of making the code that _initiates_ an API request know as little as possible about the details of _how_ it’s handled, your app’s [observers](observers.md) and [request hooks](requests.md#request-hooks) all receive fully parsed data of an app-appropriate type.

What is an “app-appropriate type?” It might be raw bytes. It might be a general-purpose data structure (e.g. a dictionary or string). It might be your “Swift does JSON” library of choice. It might be an app-specific model. Most likely it’s all of the above in sequence. The only certain thing is that one size does not fit all!

Siesta gives you control over response parsing with the [transformer pipeline](https://bustoutsolutions.github.io/siesta/api/Structs/Pipeline.html), a lightly structured sequence of transformations which Siesta applies to network responses before passing them on to your app.

Each step in the pipeline is a [`ResponseTransformer`](https://bustoutsolutions.github.io/siesta/api/Protocols/ResponseTransformer.html). Each transformer takes a [`Response`](https://bustoutsolutions.github.io/siesta/api/Enums/Response.html) and returns a `Response` (possibly identical, possibly altered). Note that a `Response` can be either a success or a failure, which means that transformers can create or alter errors.

The ultimate output of the pipeline determines whether a `Request` was successful, and for a [load request](requests.md#request-vs-load), updates either `Resource.latestData` or `Resource.latestError`.

The pipeline is part of Siesta’s [configuration mechanism](configuration.md), and like any other piece of configuration:

- You configure it as part of your `Service` setup.
- You can configure it globally, by resource pattern, and by request method.
- You can set broader defaults and override them in specific cases.

## Pipeline Stages

The pipeline is broken into a set of stages. Each feeds into the next — they function as a single sequence of transformers — but grouping them by stage gives you the flexibility to remove and replace existing ones when overriding configuration for a subset of resources.

The default stages are:

- `rawData`: unprocessed data
- `decoding`: bytes → bytes: decryption, decompression, etc.
- `parsing`: bytes → general-purpose data structure: JSON, UIImage, etc.
- `model`: data structure → model
- `cleanup`: catch-all for stuff at the end

These are only human-friendly unique identifiers; there is no special meaning or behavior attached to any of the stages.

Your app can create custom stages on a per-service or per-resource basis:

```swift
extension PipelineStageKey {
  static let
    munging   = PipelineStageKey(description: "munging"),
    twiddling = PipelineStageKey(description: "twiddling")
}
```
```swift
service.configure {
  $0.pipeline.order = [.rawData, .munging, .twiddling, .cleanup]
}
```


## Default Transformers

By default, Siesta preconfigures a `Service` with common transformers at the `parsing` stage:

- `String` for `text/*`
- `UIImage` for `image/*` (`NSImage` on macOS)
- `JSONSerialization` for `*/json`

You can disable these for a whole service using the `useDefaultTransformers:` argument to [`Service.init(…)`](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html#//apple_ref/swift/Method/init(baseURL:useDefaultTransformers:networking:)). You can also remove them for specific resources by clearing the `parsing` stage in your configuration:

```swift
service.configure("/funky/**") {
  $0.pipeline[.parsing].removeTransformers()
}
```

## Custom Transformers

The following are examples of the most common pipeline use cases. For the full menu of options, see the API docs for [`Pipeline`](https://bustoutsolutions.github.io/siesta/api/Structs/Pipeline.html) and its friends. (Most of the example code in this section comes from the GithubBrowser example project. It is helpful to [see it in context](https://github.com/bustoutsolutions/siesta/blob/master/Examples/GithubBrowser/Source/API/GithubAPI.swift).)

### Model Mapping

The most common custom pipeline configuration you’ll need to do is mapping specific API endpoints to specific models. Here, for example, we map an endpoint to the `User` model:

```swift
service.configureTransformer("/users/*") {
  User(json: $0.content)  // Input type inferred because User.init takes JSON
}
```

`$0.content` is the response content by itself. The second parameter of the closure, not used here, is the full response [`Entity`](https://bustoutsolutions.github.io/siesta/api/Structs/Entity.html), which gives access to HTTP headers.

Note that Swift infers that the type of this closure is `(JSON,Entity) -> User`, and this closure type affects the pipeline behavior. If the output of the previous transformers is not the correct input type — that is, if the pipeline didn’t give us `JSON` by the time we got to this transformer — then Siesta reports that as a failed request.

The output of your closure doesn’t need to be a model; it can be any type. This transformer, for example, returns a collection of models:

```swift
service.configureTransformer("/users/*/repos") {
  ($0.content as JSON).arrayValue  // “as JSON” gives Siesta an explicit input type
    .map(Repository.init)          // Swift can infer that the output type is [Repository]
}
```

There are no strict limitations on the type your transformer returns. The one strong recommendation is that you **make your content immutable** — either a struct or an immutable class. This helps with thread safety (transformers [run on a GCD queue](threading.md)), and ensures that you can’t change a resource’s state in place without generating a change notification.

By default, [`configureTransformer(…)`](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html#//apple_ref/swift/Method/configureTransformer(_:requestMethods:atStage:action:onInputTypeMismatch:transformErrors:description:contentTransform:)):

- operates on the `model` pipeline stage,
- replaces any existing transformers at that stage, and
- applies to all HTTP request methods (GET, POST, PUT, etc.).

Note that this method _replaces_ the transformer(s) at the stage you specify. (Use the `action:` parameter to append instead.) You can use this behavior to override previously configured transformers for specific resources:

```swift
service.configureTransformer("/funkyStuff", atStage: .parsing) {
  return funkyParse($0.content)  // This replaces default .parsing transformers
}
```

…or even override them for specific request methods:

```swift
// Array of items
service.configureTransformer("/items") {  // adds transformer at .model stage by default
  ($0.content as JSON).arrayValue.map { Item(json: $0) }
}

// POST returns a single item
service.configureTransformer("/items", requestMethods: [.post]) {  // replaces .model transformer
  Item(json: $0.content)
}
```
Although `configureTransformer(…)` is a flexible tool, it is just convenience for common cases, and has limitations:

- It only operates on successful requests, so you can’t use it to transform upstream errors.
- It only alters the response’s [`Entity.content`](https://bustoutsolutions.github.io/siesta/api/Structs/Entity.html#//apple_ref/swift/Property/content). It cannot alter HTTP headers.
- It does not let you limit the transformation to a specific `Content-type`.

There are also a few more obscure pipeline options the method does not expose.

### Custom Generic Data Structures

There are many content types that Siesta does not support by default — XML, for example (because there is no standard XML parser on iOS). When you add support for one of these types, you’ll typically want it to be based on the `Content-type` header

In this situation, create a [`ResponseContentTransformer`](https://bustoutsolutions.github.io/siesta/api/Structs/ResponseContentTransformer.html) and configure it using
[`$0.pipeline`](https://bustoutsolutions.github.io/siesta/api/Structs/Configuration.html#//apple_ref/swift/Property/pipeline). For example, the GithubBrowser project wraps all JSON responses in SwiftyJSON for the downstream model transformers:

```swift
let SwiftyJSONTransformer =
  ResponseContentTransformer
    { JSON($0.content as AnyObject) }
```
```swift
service.configure {
  $0.pipeline[.parsing].add(
    SwiftyJSONTransformer,
    contentTypes: ["*/json"])
}
```

Note that the `parsing` stage comes before the `model` stage, so the `User` and `[Repository]` transformers above will receive `JSON` values instead of dictionaries.

`ResponseContentTransformer` includes a `transformErrors:` flag, which lets you apply parsing to 4xx and 5xx responses, not just 2xx.

### Error Transformation

The [`ResponseTransformer`](https://bustoutsolutions.github.io/siesta/api/Protocols/ResponseTransformer.html) protocol is the fully generic, fully powerful, fully inconvenient way to write a transformer. It takes arbitrary `Response`s and returns arbitrary `Response`s. This involves some annoying enum unwrapping and rewrapping.

Use this when the conveniences in the sections above are too limited. For example, you’ll need this if you want to transform a failure response but leave successes untouched. For example, GithubBrowser allows the Github API to override Siesta’s default error messages:

```swift
struct GithubErrorMessageExtractor: ResponseTransformer {
  func process(_ response: Response) -> Response {
    switch response {
      case .success:
        return response

      case .failure(var error):
        error.userMessage =
          error.jsonDict["message"] as? String ?? error.userMessage
        return .failure(error)
    }
  }
}
```
```swift
service.configure {
  $0.pipeline[.cleanup].add(
    GithubErrorMessageExtractor())
}
```

Note that no matter which of these approaches you use to configure the pipeline, it runs _before_ your app receives any data. This allows Siesta to parse responses only once. That’s so important, I’m going to give it its own headline:

## Siesta Parses Responses Only Once

Why is this big news? Let’s look at what happens when it isn’t true.

Suppose you’re using Alamofire, and you find a `responseJSON(…)` callback growing large and unwieldy. You might be tempted to split it into several smaller callbacks:

```swift
// ☠☠☠ WRONG ☠☠☠
Alamofire.request(.GET, "https://myapi.example/status")
  .responseJSON { /* stop activity indicator */ }
  .responseJSON { /* update UI */ }
  .responseJSON { /* play happy sound on success */ }
  .responseJSON { /* show error message */ }
```

Now you can break that apart into nice little helpers, some of which will be generically reusable: `attachErrorHandling(toRequest:)`, `attachActivityIndicator(toRequest:)`, etc. Makes sense, right? After all, isn’t this what these separately attachable callbacks are for — composability, reuse, decoupling?

Ah, but there’s a fly in this ointment: the code above **parses the JSON four times**, once for each call to `responseJSON(…)`. In practice, `request()` and `responseJSON(…)` are tightly coupled in Alamofire, because you want to be sure to call `responseJSON(…)` only once. Drat.

Siesta does not have this problem. The following code **parses the response exactly once**, even though it registers two observers plus two request hooks: 

```swift
let resource = service.resource("/status")

resource
  .addObserver(owner: self) { /* start/stop activity indicator */ }
  .addObserver(owner: self) { /* update UI */ }

resource.load()
  .onSuccess { /* play happy sound */ }
  .onFailure { /* show error message */ }
```

Siesta’s **observers and hooks are low-cost abstractions**. Use them liberally as a tool of decomposition! You could, for example, register every visible cell in a `UICollectionView` as a separate resource observer, and things would perform just fine.

This is what [RemoteImageView](https://bustoutsolutions.github.io/siesta/api/Classes/RemoteImageView.html) does: an individual view can [directly register itself to observe](https://github.com/bustoutsolutions/siesta/blob/master/Source/UI/RemoteImageView.swift#L55-L57) the data it displays. The pipeline allows the view to do this without bloat or redundant work. Because the view has no idea how the request gets created or the response gets parsed, the view code stay clean and free of network details (especially if you put API paths and parameters in service helper methods). Because the view is directly observing the data it needs, no controller code needs to concern itself with making requests or passing along data on the view’s behalf.

That’s not to say that views should always be resource observers; rather, the point is that this separation of concerns gives you new and better options for keeping a clean house in your project. The Siesta way of thinking is a weapon against the dreaded Massive View Controller.

## Entity Cache

The transformer pipeline also supports a persistent cache to allow fast app launch and offline access. However, Siesta currently only provides the protocol and configuration points for caching; there is no built-in implementation yet. That is a post-1.0 feature; see the [release roadmap](faq.md#roadmap) for details.

For more info on writing your own cache implementation, see the [`EntityCache`](https://bustoutsolutions.github.io/siesta/api/Protocols/EntityCache.html) API docs.
