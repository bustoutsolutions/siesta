# FAQ

## Roadmap

#### Why is it “beta?” Why isn’t it 1.0?

Siesta is already in use in apps released on the App Store. In that sense, it’s production-ready software.

However, since this began as one team’s internal tool, the API was thus initially validated against only that one team’s practices. When Siesta went public, we wanted other teams to have a chance to exercise it and see how it fit into _their_ approach to app-writing before we finalized the API. This yielded many valuable insights.

Once we declare a 1.0 release, we will endeavor to follow semantic versioning — and API tweaking will become much harder at that point.

#### If it’s in beta, should I use it in my apps?

Yes! We believe the code is high quality and ready for real-world use.

However, you should be ready for breaking changes to the API until we declare an official 1.0 release. That’s what the “beta” label is warning you about.

#### What’s the plan for 1.0? How will you manage the big Swift 2 → 3 migration?
{:#roadmap-1-0}

The tentative plan is this:

- `1.0-beta.8`: new [transformer pipeline API](pipeline.md), the last major pre-1.0 API change
- `1.0-beta.9`: `EntityCache` improvements
- `1.0-beta.10`:
  - Request decorating, chaining, repeating
  - Any other final API refinements
  - split UI helpers into separate subproject
  - reorganize directory structure to anticipate SwiftPM

After these releases, when we are confident that 1.0 functionality is set, we will cut final Swift 2 releases:

- `1.0.x-swift.2.2`
- `1.0.x-swift.2.3` (maaaaybe, if there’s demand for it)

These will be the last releases to support Swift 2, except for any critical bug fixes. If you aren’t ready to move to Swift 3, you can stick with these releases.

The `master` branch will then move to Swift 3. The goal is to do this before Swift 3 goes GM. While this will be a disruptive change, it should not involve any changes in Siesta’s functionality, and the only API changes will be to adhere to the new Swift 3 naming guidelines (e.g. lowercase enums). The final 1.0 API freeze will target Swift 3 only, and with luck will happen immediately on the heels of Swift 3’s official release:

- `1.0.0-rc.*`, `1.0.0`: targeting Swift 3

Post 1.0 development will only support Swift 3.

#### What’s in the works for post-1.0 releases?

To a large extent, this is driven by user questions & requests. Please file issues on Github, ask questions on Stack Overflow, or tweet to [@siestaframework](https://twitter.com/siestaframework).

One high priority post-1.0 feature is the addition of standard [EntityCache](http://bustoutsolutions.github.io/siesta/api/Protocols/EntityCache.html) implementations, which will provide fast app start + _almost_ free offline access.


## Capabilities

#### How do I do a backgrounded multipart request that switches to streaming mode while pulling a double shot of espresso?

Find a lower-level networking library. And a barista.

Siesta is a high-level library designed to make the common behaviors of REST services simple to use. It’s an awesome way to manage your workaday REST calls, but it’s not a networking Swiss army knife.

#### What if I’m downloading huge responses, and I don’t want them held in memory all at once?

Use a lower-level networking library.

If you aren’t interested in holding a response entirely in memory, there’s little benefit to using Siesta. Siesta’s advantage over lower-level networking is the “parse once, share everywhere” nature of its observer architecture — which implies holding on to entire responses for reuse.

#### How do I control the number of concurrent requests? SSL validation? NSURLCache options?

Configure them in the underlying networking library you are using with Siesta.

From the time that it has constructed a request until the time it has a complete response, Siesta delegates all of its networking to the provider you specify. That is were all these options get configured. See the `networking:` parameter of [`Service.init(...)`](http://bustoutsolutions.github.io/siesta/api/Classes/Service.html#/s:FC6Siesta7ServicecFMS0_FT4baseGSqSS_22useDefaultTransformersSb10networkingPS_29NetworkingProviderConvertible__S0_).

#### Why doesn’t Siesta provide a typesafe `Resource<T>`?

One big future wish for Siesta is more static type safety when using custom transformers that map specific routes to specific model classes. Unfortunately, limitations of Swift’s generic type system prevent the seemingly obvious solution of a genericized `Resource<T>` from being workable in practice.

The missing feature is support for generalized existential types. There has been extensive discussion of this on [swift-evolution](https://github.com/apple/swift-evolution) ([here](http://thread.gmane.org/gmane.comp.lang.swift.evolution/17418/focus=18810), for example), but the problem proved [too large to solve in time for Swift 3](http://thread.gmane.org/gmane.comp.lang.swift.evolution/17276). That means we won’t be getting `Resource<T>` until at least Swift 4.

In the meantime, [`typedContent(…)`](https://bustoutsolutions.github.io/siesta/api/Protocols/TypedContentAccessors.html#/s:FE6SiestaPS_21TypedContentAccessors12typedContenturFT6ifNoneKT_qd___qd__) and friends get the job done.

## Contact

#### How do I ask a question that isn’t here?

Post your question to [Stack Overflow](https://stackoverflow.com) and tag it with **siesta-swift**. (Be sure to include the tag. It triggers a notification.)

If your question is short, you can also Tweet it to us at [@siestaframework](https://twitter.com/siestaframework).
