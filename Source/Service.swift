//
//  Service.swift
//  Siesta
//
//  Created by Paul on 2015/6/15.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation


/**
  A set of logically connected RESTful resources. Resources within a service share caching, configuration, and a
  “same URL → same resource” uniqueness guarantee.

  You will typically create a separate instance of `Service` for each REST API you use. You can either subclass
  `Service` or encapsulte it inside a wrapper. Regardless, to reap the benefits of Siesta, you’ll want to ensure that
  all the observers of an API share a single instance.

  You can optionally specify a `baseURL`, which allows you to get endpoints by path: `service.resource("/foo")`.
  Specifying a `baseURL` does _not_ limit the service only to subpaths of that URL. Its one and only purpose is to be
  the starting point for `resource(_:)`

  Note that `baseURL` is only a convenience, and is optional.
  If you want to group multiple base URLs in a single `Service` instance, use `resource(baseURL:path:)`.
  If you want to feed your service arbitrary URLs with no common root, use `resource(absoluteURL:)`.
*/
@objc(BOSService)
public class Service: NSObject
    {
    /// The root URL of the API. If nil, then `resource(_:)` will only accept absolute URLs.
    public let baseURL: NSURL?

    internal let networkingProvider: NetworkingProvider
    private var resourceCache = WeakCache<String,Resource>()

    /**
      Creates a new service for the given API.

      - Parameter baseURL:
          The URL underneath which the API exposes its endpoints. If nil, there is no base URL, and thus you must use
          only `resource(absoluteURL:)` and `resource(baseURL:path:)` to acquire resources.
      - Parameter useDefaultTransformers:
          If true, include handling for JSON, text, and images. If false, leave all responses as `NSData` (unless you
          add your own `ResponseTransformer` using `configure(...)`).
      - Parameter networking:
          The handler to use for networking. The default is `NSURLSession` with ephemeral session configuration. You can
          pass an `NSURLSession`, `NSURLSessionConfiguration`, or `Alamofire.Manager` to use an existing provider with
          custom configuration. You can also use your own networking library of choice by implementing `NetworkingProvider`.
    */
    public init(
            baseURL: URLConvertible? = nil,
            useDefaultTransformers: Bool = true,
            networking: NetworkingProviderConvertible = NSURLSessionConfiguration.ephemeralSessionConfiguration())
        {
        dispatch_assert_main_queue()

        if let baseURL = baseURL?.url
            {
            self.baseURL = baseURL.alterPath
                {
                path in
                !path.hasSuffix("/")
                    ? path + "/"
                    : path
                }
            }
        else
            { self.baseURL = nil }
        self.networkingProvider = networking.siestaNetworkingProvider

        super.init()

        if useDefaultTransformers
            {
            configure(description: "Siesta default response parsers")
                {
                $0.config.pipeline[.parsing].add(JSONResponseTransformer(),  contentTypes: ["*/json", "*/*+json"])
                $0.config.pipeline[.parsing].add(TextResponseTransformer(),  contentTypes: ["text/*"])
                $0.config.pipeline[.parsing].add(ImageResponseTransformer(), contentTypes: ["image/*"])
                }
            }
        }

    /**
      Returns the unique resource with the given path appended to the path component of `baseURL`.

      A leading slash is optional, and has no effect:

          service.resource("users")   // same
          service.resource("/users")  // thing

      - Note:
          The `path` parameter is simply appended to `baseURL`’s path, and is _never_ interpreted as a URL. Strings
          such as `..`, `//`, `?`, and `https:` have no special meaning; they go directly into the resulting
          resource’s path, with escaping if necessary.

          If you want to pass an absolute URL, use `resource(absoluteURL:)`.

          If you want to pass a relative URL to be resolved against `baseURL`, use `resource("/").relative(relativeURL)`.
    */
    @warn_unused_result
    @objc(resource:)
    public final func resource(path: String) -> Resource
        {
        return resource(baseURL: baseURL, path: path)
        }

    /**
      Returns the unique resource with the given path appended to `customBaseURL`’s path, ignoring the service’s
      `baseURL` property.

      As with `resource(_:)`:

      - leading slashes on `path` are optional and have no effect, and
      - `path` is _always_ escaped if necessary so that it is part of the URL’s path, and is never interpreted as a
        query string or a relative URL.
    */
    @warn_unused_result
    public final func resource(baseURL customBaseURL: URLConvertible?, path: String) -> Resource
        {
        return resource(absoluteURL:
            customBaseURL?.url?.URLByAppendingPathComponent(path.stripPrefix("/")))
        }

    private static let invalidURL = NSURL(string: "")!     // URL we use when given bad URL for a resource

    /**
      Returns the unique resource with the given URL, ignoring `baseURL`.

      This method will _always_ return the same instance of `Resource` for the same URL within
      the context of a `Service` as long as anyone retains a reference to that resource.
      Unreferenced resources remain in memory (with their cached data) until a low memory event
      occurs, at which point they are summarily evicted.

      - Note: This method always returns a `Resource`, and does not throw errors. If `url` is nil (likely because it
              came from a malformed URL string), this method returns a resource whose requests always fail.
    */
    @warn_unused_result
    public final func resource(absoluteURL urlConvertible: URLConvertible?) -> Resource
        {
        dispatch_assert_main_queue()

        guard let url = urlConvertible?.url else
            {
            debugLog(.Network, ["WARNING: Invalid URL:", urlConvertible, "(all requests for this resource will fail)"])
            return resource(absoluteURL: Service.invalidURL)
            }

        return resourceCache.get(url.absoluteString)
            {
            Resource(service: self, url: url)
            }
        }

    // MARK: Resource Configuration

    internal var configVersion: UInt64 = 0
    private var configurationEntries: [ConfigurationEntry] = []
        {
        didSet { invalidateConfiguration() }
        }

    /**
      Applies configuration to resources whose URLs match a given pattern.

      Examples:

          configure { $0.config.expirationTime = 10 }  // global default

          configure("/items")    { $0.config.expirationTime = 5 }
          configure("/items/​*")  { $0.config.headers["Funkiness"] = "Very" }
          configure("/admin/​**") { $0.config.headers["Auth-token"] = token }

          let user = resource("/user/current")
          configure(user) { $0.config.persistentCache = userProfileCache }

      Configuration closures apply to any resource they match, in the order they were added, whether global or not. That
      means that you will usually want to add your global configuration first, then resource-specific configuration.

      If you want to provide global configuration, or if you need more fine-grained URL matching, use the other flavor
      of this method that takes a predicate as its first argument.

      - Parameter pattern:
          Selects the subset of resources to which this configuration applies. You can pass a `String`, `Resource`, or
          `NSRegularExpression` for the `pattern` argument — or write your own custom implementation of
          `ConfigurationPatternConvertible`.
      - Parameter description:
          An optional description of this piece of configuration, for logging and debugging purposes.
      - Parameter configurer:
          A closure that receives a mutable `Configuration`, referenced as `$0.config`, which it may modify as it
          sees fit. This closure will be called whenever Siesta needs to generate or refresh configuration. You should
          not rely on it being called at any particular time, and should avoid making it cause side effects.

      - SeeAlso: `configure(whenURLMatches:requestMethods:description:configurer:)`
          for global config and more fine-grained matching
      - SeeAlso: `invalidateConfiguration()`
      - SeeAlso: For more details about the rules of pattern matching:
        - `String.configurationPattern(_:)`
        - `Resource.configurationPattern(_:)`
        - `NSRegularExpression.configurationPattern(_:)`
    */
    public final func configure(
            pattern: ConfigurationPatternConvertible,
            requestMethods: [RequestMethod]? = nil,
            description: String? = nil,
            configurer: Configuration.Builder -> Void)
        {
        configure(
            whenURLMatches: pattern.configurationPattern(self),
            requestMethods: requestMethods,
            description: description ?? pattern.configurationPatternDescription,
            configurer: configurer)
        }

    /**
      Applies configuration to resources whose URL matches an arbitrary predicate.
      Use this if the wildcards in the `urlPattern` flavor of `configure()` aren’t robust enough.

      If you do not supply a predicate, then the configuration applies globally to all resources in this service.

      - Parameter whenURLMatches:
          A predicate that matches absolute URLs of resources. The default is a predicate that matches anything.

      - SeeAlso: `configure(_:requestMethods:description:configurer:)`
          for pattern-based matching, and for details about the parameters.
      - SeeAlso: `invalidateConfiguration()`
    */
    public final func configure(
            whenURLMatches configurationPattern: NSURL -> Bool = { _ in true },
            requestMethods: [RequestMethod]? = nil,
            description: String? = nil,
            configurer: Configuration.Builder -> Void)
        {
        dispatch_assert_main_queue()

        let entry = ConfigurationEntry(
            description: "config \(nextConfigID) [" + (description ?? "custom") + "]",
            requestMethods: Set(requestMethods ?? RequestMethod.all),
            configurationPattern: configurationPattern,
            configurer: configurer)
        configurationEntries.append(entry)
        debugLog(.Configuration, ["Added", entry])
        }

    /**
      Transforms responses by passing their content through the given closure. This is a shortcut for adding a
      `ResponseContentTransformer` to the `Configuration.responseTransformers`.

      Useful for transformers that create model objects. For example:

          configureTransformer("/foo/​*") {
            FooModel(json: $0.content)
          }

      Siesta checks that the incoming `Entity.content` matches the type of the closure’s `content` parameter. In the
      example code above, if the `json` parameter of `FooModel.init` takes a `Dictionary`, but the transformer pipeline
      at that point has produced a `String`, then the transformer outputs a failure response.

      You can use this behavior to configure a service to refuse all server responses not of a specific type by passing
      a transformer that passes the content through unmodified, but requires a specific type:

          service.configureTransformer("**") {
            $0.content as NSJSONConvertible
          }

      - SeeAlso: `configure(_:requestMethods:description:configurer:)`
          for more into about the parameters and configuration pattern matching.
      - SeeAlso: `ResponseContentTransformer`
          for more robust transformation options.
    */
    public final func configureTransformer<I,O>(
            pattern: ConfigurationPatternConvertible,
            atStage stage: PipelineStageKey = .model,
            action: PipelineStage.MutationAction = .replaceExisting,
            requestMethods: [RequestMethod]? = nil,
            description: String? = nil,
            contentTransform: ResponseContentTransformer<I,O>.Processor)
        {
        func defaultDescription() -> String
            {
            let methodsDescription: String
            if let requestMethods = requestMethods
                { methodsDescription = String(requestMethods) }
            else
                { methodsDescription = "" }

            return pattern.configurationPatternDescription
                 + methodsDescription
                 + " : \(I.self) → \(O.self)"
            }

        configure(pattern, requestMethods: requestMethods, description: description ?? defaultDescription())
            {
            if action == .replaceExisting
                { $0.config.pipeline[stage].removeTransformers() }

            $0.config.pipeline[stage].add(
                ResponseContentTransformer(processor: contentTransform))
            }
        }

    private var configID = 0
    private var nextConfigID: Int
        {
        configID += 1
        return configID - 1
        }

    /**
      Signals that all resources need to recompute their configuration next time they need it.

      Because the `configure(...)` methods accept an arbitrary closure, it is possible that the results of
      that closure could change over time. However, resources cache their configuration after it is computed. Therefore,
      if you do anything that would change the result of a configuration closure, you must call
      `invalidateConfiguration()` in order for the changes to take effect.

      _《insert your functional programming purist rant here if you so desire》_

      Note that you do _not_ need to call this method after calling any of the `configure(...)` methods.
      You only need to call it if one of the previously passed closures will now behave differently.

      For example, to make a header track the value of a modifiable property:

          var flavor: String {
            didSet { invalidateConfiguration() }
          }

          init() {
            super.init(baseURL: "https://api.github.com")
            configure​ {
              $0.config.headers["Flavor-of-the-month"] = self.flavor  // NB: use weak self if service isn’t a singleton
            }
          }

      Note that this method does _not_ immediately recompute all existing configurations. This is an inexpensive call.
      Configurations are computed lazily, and the (still relatively low) performance impact of recomputation is spread
      over subsequent resource interactions.
    */
    public final func invalidateConfiguration()
        {
        dispatch_assert_main_queue()

        if anyConfigSinceLastInvalidation
            { debugLog(.Configuration, ["Configurations need to be recomputed"]) }
        anyConfigSinceLastInvalidation = false

        configVersion += 1
        }

    private var anyConfigSinceLastInvalidation = false

    internal func configuration(forResource resource: Resource, requestMethod: RequestMethod) -> Configuration
        {
        anyConfigSinceLastInvalidation = true
        debugLog(.Configuration, ["Computing configuration for", requestMethod, resource])
        let builder = Configuration.Builder()
        for entry in configurationEntries
            where entry.requestMethods.contains(requestMethod)
               && entry.configurationPattern(resource.url)
            {
            debugLog(.Configuration, ["Applying", entry, "to", resource])
            entry.configurer(builder)
            }
        return builder.config
        }

    private struct ConfigurationEntry: CustomStringConvertible
        {
        let description: String
        let requestMethods: Set<RequestMethod>
        let configurationPattern: NSURL -> Bool
        let configurer: Configuration.Builder -> Void
        }

    // MARK: Wiping state

    /**
      Wipes the state of all this service’s resources. Typically used to handle logout.

      Applies to resources matching the predicate, or all resources by default.
    */
    public final func wipeResources(@noescape predicate: Resource -> Bool =  { _ in true })
        {
        dispatch_assert_main_queue()

        resourceCache.flushUnused()
        for resource in resourceCache.values
            where predicate(resource)
                { resource.wipe() }
        }

    /**
      Wipes resources based on a URL pattern. For example:

          service.wipeResources("/secure/​**")
          service.wipeResources(profileResource)
    */
    public final func wipeResources(pattern: ConfigurationPatternConvertible)
        {
        wipeResourcesMatchingURL(pattern.configurationPattern(self))
        }

    /**
      Wipes the state of a subset of this service’s resources, matching based on URLs (instead of `Resource` instances).

      Useful for making shared predicates that you can pass to both `configure(...)` and this method.
    */
    public final func wipeResourcesMatchingURL(@noescape predicate: NSURL -> Bool)
        {
        wipeResources { predicate($0.url) }
        }

    // MARK: General Configuration

    /**
      Soft limit on the number of resources cached in memory. If the internal cache size exceeds this limit, Siesta
      flushes all unused resources. Note that any resources still in use — i.e. retained outside of Siesta — will remain
      in the cache, no matter how many there are.
    */
    public var cachedResourceCountLimit: Int
        {
        get { return resourceCache.countLimit }
        set { resourceCache.countLimit = newValue }
        }
    }
