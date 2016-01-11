//
//  Service.swift
//  Siesta
//
//  Created by Paul on 2015/6/15.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Foundation


/**
  A set of logically connected RESTful resources, grouped under a base URL.

  You will typically create a separate subclass of `Service` for each REST API you use.
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
          only `resource(absoluteURL:)` to acquire resources.
      - Parameter useDefaultTransformers:
          If true, include handling for JSON, text, and images. If false, leave all responses as `NSData` (unless you
          add your own `ResponseTransformer` using `configure(...)`).
      - Parameter networking:
          The handler to use for networking. The default is an NSURLSession with its default configuration. You can
          pass an `NSURLSession`, `NSURLSessionConfiguration`, or `Alamofire.Manager` to use an existing provider with
          custom configuration. You can also use your own networking library of choice by implementing `NetworkingProvider`.
    */
    public init(
            baseURL: String? = nil,
            useDefaultTransformers: Bool = true,
            networking: NetworkingProviderConvertible = NSURLSessionConfiguration.ephemeralSessionConfiguration())
        {
        dispatch_assert_main_queue()

        if let baseURL = baseURL
            {
            self.baseURL = NSURL(string: baseURL)?.alterPath
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
            configure(description: "Siesta default response transformers")
                {
                $0.config.responseTransformers.add(JSONResponseTransformer(),  contentTypes: ["*/json", "*/*+json"])
                $0.config.responseTransformers.add(TextResponseTransformer(),  contentTypes: ["text/*"])
                $0.config.responseTransformers.add(ImageResponseTransformer(), contentTypes: ["image/*"])
                }
            }
        }

    /**
      Return the unique resource with the given path appended to the path component of `baseURL`.

      A leading slash is optional, and has no effect:

          service.resource("users")   // same
          service.resource("/users")  // thing

      - Note:
          The `path` parameter is simply appended to `baseURL`’s path, and is _never_ interpreted as a URL. Strings
          such as `..`, `//`, `?`, and `https:` have no special meaning; they go directly into the resulting
          resource’s path.

          If you want to pass an absolute URL, use `resource(absoluteURL:)`.

          If you want to pass a relative URL to be resolved against `baseURL`, use `resource("/").relative(relativeURL)`.
    */
    @warn_unused_result
    @objc(resource:)
    public final func resource(path: String) -> Resource
        {
        return resource(absoluteURL:
            baseURL?.URLByAppendingPathComponent(path.stripPrefix("/")))
        }

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
    @objc(resourceWithAbsoluteURL:)
    public final func resource(absoluteURL url: NSURL?) -> Resource
        {
        dispatch_assert_main_queue()

        let key = url?.absoluteString ?? ""
        return resourceCache.get(key)
            {
            Resource(service: self, url: url ?? Service.invalidURL)
            }
        }

    private static let invalidURL = NSURL(string: "")!     // URL we use when given bad URL for a resource

    /**
      Returns the unique resource with the given URL string, ignoring `baseURL`.

      - SeeAlso: `resource(absoluteURL:)`
    */
    @warn_unused_result
    @objc(resourceWithAbsoluteURLString:)
    public final func resource(absoluteURL urlString: String?) -> Resource
        {
        guard let urlString = urlString else
            { return resource(absoluteURL: Service.invalidURL) }

        let url = NSURL(string: urlString)
        if url == nil
            { debugLog(.Network, ["WARNING: Invalid URL:", urlString, "(all requests for this resource will fail)"]) }
        return resource(absoluteURL: url)
        }

    // MARK: Resource Configuration

    internal var configVersion: UInt64 = 0
    private var configurationEntries: [ConfigurationEntry] = []
        {
        didSet { invalidateConfiguration() }
        }

    /**
      Applies global configuration to all resources in this service. The `configurer` closure receives a mutable
      `Configuration`, referenced as `$0.config`, which it may modify as it sees fit.

      For example:

          service.configure { $0.config.headers["Foo"] = "bar" }

      The `configurer` block is evaluated every time a matching resource asks for its configuration.

      The optional `description` is used for logging purposes only.

      Configuration closures apply to any resource they match in the order they were added, whether global or not. That
      means that you will usually want to add your global configuration first, then resource-specific configuration.

      - SeeAlso: `configure(_:description:configurer:)`
      - SeeAlso: `invalidateConfiguration()`
    */
    public final func configure(
            description description: String = "global",
            configurer: Configuration.Builder -> Void)
        {
        configure(
            { _ in true },
            description: description,
            configurer: configurer)
        }

    /**
      Applies configuration to resources matching the given pattern. You can pass a `String` or `Resource` for the
      `pattern` argument, or provide your own implementation of `ConfigurationPatternConvertible`.

      Examples:

          configure("/items")    { $0.config.expirationTime = 5 }
          configure("/items/​*")  { $0.config.headers["Funkiness"] = "Very" }
          configure("/admin/​**") { $0.config.headers["Auth-token"] = token }

          let user = resource("/user/current")
          configure(user) { $0.config.persistentCache = userProfileCache }

      If you need more fine-grained URL matching, use the predicate flavor of this method.

      - SeeAlso: `configure(description:configurer:)` for global config
      - SeeAlso: `invalidateConfiguration()`
    */
    public final func configure(
            pattern: ConfigurationPatternConvertible,
            description: String? = nil,
            configurer: Configuration.Builder -> Void)
        {
        configure(
            pattern.configurationPattern(self),
            description: description ?? pattern.configurationPatternDescription,
            configurer: configurer)
        }

    /**
      Accepts an arbitrary URL matching predicate if the wildcards in the `urlPattern` flavor of `configure()`
      aren’t robust enough.
    */
    public final func configure(
            configurationPattern: NSURL -> Bool,
            description: String? = nil,
            configurer: Configuration.Builder -> Void)
        {
        dispatch_assert_main_queue()

        let entry = ConfigurationEntry(
            description: "config \(nextConfigID) [" + (description ?? "custom") + "]",
            configurationPattern: configurationPattern,
            configurer: configurer)
        configurationEntries.append(entry)
        debugLog(.Configuration, ["Added", entry])
        }

    /**
      A convenience to add a one-off content transformer.

      Useful for transformers that create model objects. For example:

          configureTransformer("/foo/​*") { FooModel(json: $0) }

      - SeeAlso: ResponseContentTransformer
    */
    public final func configureTransformer<I,O>(
            pattern: ConfigurationPatternConvertible,
            description: String? = nil,
            contentTransform: ResponseContentTransformer<I,O>.Processor)
        {
        configure(pattern, description: description ?? "\(pattern.configurationPatternDescription) : \(I.self) → \(O.self)")
            {
            $0.config.responseTransformers.add(
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

    internal func configurationForResource(resource: Resource) -> Configuration
        {
        anyConfigSinceLastInvalidation = true
        debugLog(.Configuration, ["Computing configuration for", resource])
        let builder = Configuration.Builder()
        for entry in configurationEntries
            where entry.configurationPattern(resource.url)
            {
            debugLog(.Configuration, ["Applying", entry, "to", resource])
            entry.configurer(builder)
            }
        return builder.config
        }

    private struct ConfigurationEntry: CustomStringConvertible
        {
        let description: String
        let configurationPattern: NSURL -> Bool
        let configurer: Configuration.Builder -> Void
        }

    // MARK: Wiping state

    /**
      Wipes the state of this service’s resources. Typically used to handle logout.

      Applies to resources matching the predicate, or all resources by default.
    */
    public final func wipeResources(predicate: Resource -> Bool =  { _ in true })
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
    public final func wipeResourcesMatchingURL(predicate: NSURL -> Bool)
        {
        wipeResources { (res: Resource) in predicate(res.url) }
        }
    }


/**
  A type that can serve as a URL matcher for service configuration.

  Siesta provides implementations of this protocol for `String` (for glob-based matching) and `Resource` (to configure
  one specific resource).

  - SeeAlso: `Service.configure(_:description:configurer:)`
  - SeeAlso: `String.configurationPattern(_:)`
  - SeeAlso: `Resource.configurationPattern(_:)`
*/
public protocol ConfigurationPatternConvertible
    {
    /// Turns the receiver into a predicate that matches URLs.
    func configurationPattern(service: Service) -> NSURL -> Bool

    /// A logging-friendly description of the receiver when it acts as a URL pattern.
    var configurationPatternDescription: String { get }
    }

/**
  Support for passing URL patterns with wildcards to `Service.configure(...)`.
*/
extension String: ConfigurationPatternConvertible
    {
    /**
      Matches URLs using shell-like wildcards / globs.

      The `urlPattern` is interpreted relative to the service’s base URL unless it begins with a protocol (e.g. `http:`).
      If it is relative, the leading slash is optional.

      The pattern supports two wildcards:

      - `*` matches zero or more characters within a path segment, and
      - `**` matches zero or more characters across path segments, with the special case that `/**/` matches `/`.

      Examples:

      - `/foo/*/bar` matches `/foo/1/bar` and  `/foo/123/bar`.
      - `/foo/**/bar` matches `/foo/bar`, `/foo/123/bar`, and `/foo/1/2/3/bar`.
      - `/foo*/bar` matches `/foo/bar` and `/food/bar`.

      The pattern ignores the resource’s query string.
    */
    public func configurationPattern(service: Service) -> NSURL -> Bool
        {
        // If the pattern has a URL protocol (e.g. "http:"), interpret it as absolute.
        // If the service has no baseURL, interpret the pattern as absolure.
        // Otherwise, interpret pattern as relative to baseURL.

        let resolvedPattern: String
        if let prefix = service.baseURL?.absoluteString where !containsRegex("^[a-z]+:")
            { resolvedPattern = prefix + stripPrefix("/") }
        else
            { resolvedPattern = self }

        let pattern = NSRegularExpression.compile(
            "^"
            + NSRegularExpression.escapedPatternForString(resolvedPattern)
                .replacingString("\\*\\*\\/", "([^:?]*/|)")
                .replacingString("\\*\\*",    "[^:?]*")
                .replacingString("\\*",       "[^/:?]*")
            + "($|\\?)")
        debugLog(.Configuration, ["URL pattern", self, "compiles to regex", pattern.pattern])

        return { pattern.matches($0.absoluteString) }
        }

    /// :nodoc:
    public var configurationPatternDescription: String
        { return self }
    }

/**
  Support for passing a specific `Resource` to `Service.configure(...)`.
*/
extension Resource: ConfigurationPatternConvertible
    {
    /**
      Matches this specific resource when passed as a pattern to `Service.configure(...)`.
    */
    public func configurationPattern(service: Service) -> NSURL -> Bool
        {
        let resourceURL = url  // prevent resource capture in closure
        return { $0 == resourceURL }
        }

    /// :nodoc:
    public var configurationPatternDescription: String
        { return url.absoluteString }
    }
