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
    /// The root URL of the API.
    public let baseURL: NSURL?
    
    internal let transportProvider: TransportProvider
    private var resourceCache = WeakCache<String,Resource>()
    
    /**
      Creates a new service for the given API.
      
      - Parameter: base The base URL of the API.
      - Parameter: base The base URL of the API.
      - Parameter: transportProvider A provider to use for networking. The default is Alamofire with its default
          configuration. You can pass an `AlamofireTransportProvider` created with a custom configuration,
          or provide your own networking implementation.
    */
    public init(
            base: String,
            config: Configuration = Configuration.withDefaultTransformers,
            transportProvider: TransportProvider = AlamofireTransportProvider())
        {
        self.baseURL = NSURL(string: base.URLString)?.alterPath
            {
            path in
            !path.hasSuffix("/")
                ? path + "/"
                : path
            }
        self.globalConfig = config
        self.transportProvider = transportProvider
        
        super.init()
        }
    
    /**
      Returns the unique resource with the given URL.
     
      This method will _always_ return the same instance of `Resource` for the same URL within
      the context of a `Service` as long as anyone retains a reference to that resource.
      Unreferenced resources remain in memory (with their cached data) until a low memory event
      occurs, at which point they are summarily evicted.
    */
    @objc(resourceWithURL:)
    public func resource(url: NSURL?) -> Resource
        {
        let key = url?.absoluteString ?? ""  // TODO: handle invalid URLs
        return resourceCache.get(key)
            {
            Resource(service: self, url: url)
            }
        }
    
    /// Return the unique resource with the given path relative to `baseURL`.
    @objc(resourceWithPath:)
    public func resource(path: String) -> Resource
        {
        return resource(baseURL?.URLByAppendingPathComponent(path.stripPrefix("/")))
        }
    
    // MARK: Resource Configuration
    
    /**
      Configuration to apply by default to all resources in this service.
      
      Changes to this struct are live: they affect subsequent requests even on resource instances that already exist.
      
      - SeeAlso: `configureResources(_:configMutator:)`
    */
    public var globalConfig: Configuration
        {
        didSet { configChanged() }
        }
    internal var globalConfigVersion: Int = 0
    private var resourceConfigurers: [Configurer] = []
    
    /**
      Applies additional configuration to resources matching the given pattern.
      
      When determining configuration for a resource, the service starts with `globalConfig`, then applies any matching
      configuration mutators in the order they were added.
      
      For example:
      
          configureResources("/items")    { $0.config.expirationTime = 5 }
          configureResources("/items/​*")  { $0.config.headers["Funkiness"] = "Very" }
          configureResources("/admin/​**") { $0.config.headers["Auth-token"] = token }
    
      The `urlPattern` is interpreted relative to the service’s base URL unless it begins with a protocol (e.g. `http:`).
      If it is relative, the leading slash is optional.
      
      The pattern supports two wildcards:
      
      - `*` matches a single path segment, and
      - `**` matches any number of paths segments, including zero. The pattern `/foo/**/bar` matches
        `/foo/bar` as well as `/foo/1/2/3/bar`.
    
      The pattern ignores the resource’s query string.
    
      - SeeAlso: `globalConfig`
      - SeeAlso: `configChanged()`
    */
    public func configureResources(
            urlPattern: String,
            configMutator: Configuration.Builder -> Void)
        {
        let prefix = urlPattern.containsRegex("^[a-z]+:")
            ? baseURL!.absoluteString  // If pattern has a protocol, interpret as absolute URL
            : ""                       // Already an absolute URL
        let resolvedPattern = prefix + urlPattern.stripPrefix("/")
        let pattern = NSRegularExpression.compile(
            NSRegularExpression.escapedPatternForString(resolvedPattern)
                .replaceString("\\*\\*\\/", "([^:?]*/|)")
                .replaceString("\\*\\*",    "[^:?]*")
                .replaceString("\\*",       "[^/:?]+")
                + "$|\\?")
        
        debugLog(.Configuration, ["URL pattern", urlPattern, "compiles to regex", pattern.pattern])
        
        configureResources(
            urlPattern,
            predicate: { pattern.matches($0.absoluteString) },
            configMutator: configMutator)
        }
    
    /**
      Accepts an arbitrary URL matching predicate if the wildcards in the other flavor of `configureResources`
      aren’t robust enough.
    */
    public func configureResources(
            debugName: String,
            predicate urlMatcher: NSURL -> Bool,
            configMutator: Configuration.Builder -> Void)
        {
        resourceConfigurers.append(
            Configurer(
                name: debugName,
                urlMatcher: urlMatcher,
                configMutator: configMutator))
        
        configChanged()
        }
    
    /**
      Signals that all resources need to recompute their configuration next time they need it.
      
      Because `configureResources(_:configMutator:)` accepts an arbitrary closure, it is possible that the results of
      that closure could change over time. However, resources cache their configuration after it is computed. Therefore,
      if you do anything that would change the result of a configuration closure, you must call `configChanged()` in
      order for the changes to take effect.
      
      For example, to make a header track the value of a modifiable property:

          var flavor: String {
            didSet { configChanged() }
          }

          init() {
            super.init(base: "https://api.github.com")
            configureResources("​**") {
              $0.config.headers["Flavor-of-the-month"] = flavor
            }
          }
    */
    public func configChanged()
        {
        globalConfigVersion++
        }
    
    internal func configurationForResource(resource: Resource) -> Configuration
        {
        debugLog(.Configuration, ["Recomputing configuration for", resource])
        let builder = Configuration.Builder(from: globalConfig)
        for configurer in resourceConfigurers
            {
            let matches = configurer.urlMatcher(resource.url!)
            debugLog(.Configuration, [configurer.name, (matches ? "matches" : "does not match"), resource])
            if matches
                { configurer.configMutator(builder) }
            }
        return builder.config
        }
    
    private struct Configurer
        {
        let name: String
        let urlMatcher: NSURL -> Bool
        let configMutator: Configuration.Builder -> Void
        }
    }
