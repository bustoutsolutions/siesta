# FAQ

## Roadmap

#### What’s in the works for future releases?
{:#roadmap}

To a large extent, this is driven by user questions & requests. Please file issues on Github, ask questions on Stack Overflow, or tweet to [@siestaframework](https://twitter.com/siestaframework).

One high priority feature is the addition of standard [EntityCache](https://bustoutsolutions.github.io/siesta/api/Protocols/EntityCache.html) implementations, which will provide fast app start + _almost_ free offline access.

#### What if I’m still on an older version of Swift, and can’t build Siesta?

There are branches (e.g. `swift-2.2`) that mark versions of Siesta that work with older Swifts.

CocoaPods:

```
pod 'Siesta', git: 'https://github.com/bustoutsolutions/siesta.git', branch: 'swift-2.2'
```

Carthage:

```
github "bustoutsolutions/siesta" "swift-2.2"
```

Look at the [list of project branches](https://github.com/bustoutsolutions/siesta/branches/all?query=swift-).


## Capabilities

#### Why doesn’t Siesta provide a typesafe `Resource<T>`?

One big future wish for Siesta is more static type safety when using custom transformers that map specific routes to specific model classes. Unfortunately, limitations of Swift’s generic type system prevent the seemingly obvious solution of a genericized `Resource<T>` from being workable in practice.

The missing feature is support for generalized existentials. There has been extensive discussion of this — there’s even a [manifesto](https://github.com/apple/swift/blob/master/docs/GenericsManifesto.md#generalized-existentials)! — but the problem has proved large and has been repeatedly deferred. That means we won’t be getting `Resource<T>` until some far future version of Swift.

In the meantime, [`typedContent(…)`](https://bustoutsolutions.github.io/siesta/api/Protocols/TypedContentAccessors.html#//apple_ref/swift/Method/typedContent(ifNone:)) and friends get the job done.

#### How do I do a backgrounded multipart request that switches to streaming mode while pulling a double shot of espresso?

Find a lower-level networking library. And a barista.

Siesta is a high-level library designed to make the common behaviors of REST services simple to use. It’s an awesome way to manage your workaday REST calls, but it’s not a networking Swiss army knife.

#### What if I’m downloading huge responses, and I don’t want them held in memory all at once?

Use a lower-level networking library.

If you aren’t interested in holding a response entirely in memory, there’s little benefit to using Siesta. Siesta’s advantage over lower-level networking is the “parse once, share everywhere” nature of its observer architecture — which implies holding on to entire responses for reuse.

#### How do I control the number of concurrent requests? SSL validation? URLCache options?

Configure them in the underlying networking library you are using with Siesta.

From the time that it has constructed a request until the time it has a complete response, Siesta delegates all of its networking to the provider you specify. That is where all these options get configured. See the `networking:` parameter of [`Service.init(...)`](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html#//apple_ref/swift/Method/init(baseURL:useDefaultTransformers:networking:)).

## Contact

#### How do I ask a question that isn’t here?

Post your question to [Stack Overflow](https://stackoverflow.com/questions/tagged/siesta-swift) and tag it with **siesta-swift**. (Be sure to include the tag. It triggers a notification.)

If your question is short, you can also Tweet it to us at [@siestaframework](https://twitter.com/siestaframework).
