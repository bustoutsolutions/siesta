# FAQ

## Roadmap

#### Why is it “beta?” Why isn’t it 1.0?

Siesta is already in use in apps released on the App Store. In that sense, it’s production-ready software.

However, since this began as one team’s internal tool, the API was thus initially validated against that one team’s practices. Now that Siesta is public, we want other teams to have a chance to exercise it and see how it fits into _their_ approach to app-writing before we finalize the API. Once we declare a 1.0 release, we will endeavor to follow semantic versioning — and API tweaking will become much harder at that point.

#### If it’s in beta, should I use it in my apps?

Yes! We believe the code is high quality and ready for real-world use.

However, you should be ready for minor breaking changes to the API until we declare an official 1.0 release. That’s what the “beta” label is warning you about.

#### What’s in the works for future releases?

To a large extent, this is driven by user questions & requests. Please file issues on Github, ask questions on Stack Overflow, or [tweet to us](https://twitter.com/siestaframework).

The thing currently at the top of our wish list is more type safety when using custom transformers that map specific routes to specific model classes. Limitations of Swift’s generic type system — at least as it stands in 2.x — prevent the seemingly obvious solution of a genericized `Resource<T>` from being workable in practice. We’re investigating workarounds and alternatives, and hoping that Swift 3.0 brings improvements to the type system.


## Capabilities

#### How do I do a backgrounded multipart request that switches to streaming mode while pulling a double shot of espresso?

Find a lower-level networking library. And a barista.

Siesta is a high-level library designed to make the common behaviors of REST services simple to use. It’s an awesome way to manage your workaday REST calls, but it’s not a networking Swiss army knife.

#### What if I’m downloading huge responses, and I don’t want them held in memory all at once?

Use a lower-level networking library.

If you aren’t interested in holding a response entirely in memory, there’s little benefit to using Siesta. Siesta’s advantage over lower-level networking is the “parse once, share everywhere” nature of its observer architecture — which implies holding on to entire responses for reuse.

#### How do I control the number of concurrent requests? SSL validation? NSURLCache options?

Configure them in the underlying networking library you are using with Siesta.

From the time that it has constructed a request until the time it has a complete response, Siesta delegates its networking layer you specify. That is were all these options get configured. See the `networking:` parameter of [`Service.init(...)`](http://bustoutsolutions.github.io/siesta/api/Classes/Service.html#/s:FC6Siesta7ServicecFMS0_FT4baseGSqSS_22useDefaultTransformersSb10networkingPS_29NetworkingProviderConvertible__S0_).


## Contact

#### How do I ask a question that isn’t here?

Post your question to [Stack Overflow](https://stackoverflow.com) and tag it with **siesta-swift**. (Be sure to include the tag. It triggers a notification.)

If your question is short, you can also Tweet it to us at [@siestaframework](https://twitter.com/siestaframework).
