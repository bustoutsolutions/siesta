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
      
      - Parameter base:
          The base URL of the API. If nil, there is no base URL, and thus `resource(_:)` will require absolute URLs.
      - Parameter useDefaultTransformers:
          If true, include handling for JSON, text, and images. If false, leave all responses as `NSData` (unless you
          add your own `ResponseTransformer` using `configure(...)`).
      - Parameter networking:
          The handler to use for networking. The default is an NSURLSession with its default configuration. You can
          pass an `NSURLSession`, `NSURLSessionConfiguration`, or `Alamofire.Manager` to use an existing provider with
          custom configuration. You can also use your own networking library of choice by implementing `NetworkingProvider`.
    */
    public init(
            base: String? = nil,
            useDefaultTransformers: Bool = true,
            networking: NetworkingProviderConvertible = NSURLSessionConfiguration.defaultSessionConfiguration())
        {
        if let base = base
            {
            self.baseURL = NSURL(string: base)?.alterPath
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
      Returns the unique resource with the given URL.
     
      This method will _always_ return the same instance of `Resource` for the same URL within
      the context of a `Service` as long as anyone retains a reference to that resource.
      Unreferenced resources remain in memory (with their cached data) until a low memory event
      occurs, at which point they are summarily evicted.
      
      If the given resource is nil (likely indicating that it came from a malformed URL string), this method _does_
      return a resource — but that resource will give errors for all requests without touching the network.
    */
    @objc(resourceWithURL:)
    public final func resource(url url: NSURL?) -> Resource
        {
        let key = url?.absoluteString ?? ""
        return resourceCache.get(key)
            {
            Resource(service: self, url: url ?? Service.invalidURL)
            }
        }

    /**
      Returns the unique resource with the given URL string. If the string is not a valid URL, this method returns a
      resource that always fails.
    */
    @objc(resourceWithURLString:)
    public final func resource(url urlString: String?) -> Resource
        {
        // TODO: consider returning nil if url is nil (and use invalidURL only for URL parse errors)
        if let urlString = urlString, let nsurl = NSURL(string: urlString)
            { return resource(url: nsurl) }
        else
            {
            if let urlString = urlString  // No warning for nil URL
                { debugLog(.Network, ["WARNING: Invalid URL:", urlString, "(all requests for this resource will fail)"]) }
            return resource(url: Service.invalidURL)
            }
        }

    private static let invalidURL = NSURL(string: "")!     // URL we use when given bad URL for a resource
    
    /// Return the unique resource with the given path appended to `baseURL`.
    /// Leading slash is optional, and has no effect.
    @objc(resourceWithPath:)
    public final func resource(path: String) -> Resource
        {
        return resource(url:
            baseURL?.URLByAppendingPathComponent(path.stripPrefix("/")))
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
    private var nextConfigID: Int { return configID++ }
    
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
            super.init(base: "https://api.github.com")
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
        if anyConfigSinceLastInvalidation
            { debugLog(.Configuration, ["Configurations need to be recomputed"]) }
        anyConfigSinceLastInvalidation = false
        
        configVersion++
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
        resourceCache.flushUnused()
        for resource in resourceCache.values
            {
            if predicate(resource)
                { resource.wipe() }
            }
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
        let prefix = containsRegex("^[a-z]+:")
            ? ""                               // If pattern has a protocol, interpret as absolute URL
            : service.baseURL!.absoluteString  // Pattern is relative to API base
        let resolvedPattern = prefix + stripPrefix("/")
        let pattern = NSRegularExpression.compile(
            NSRegularExpression.escapedPatternForString(resolvedPattern)
                .replaceString("\\*\\*\\/", "([^:?]*/|)")
                .replaceString("\\*\\*",    "[^:?]*")
                .replaceString("\\*",       "[^/:?]*")
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
