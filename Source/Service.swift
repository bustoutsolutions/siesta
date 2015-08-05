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
    
    /**
      A sequence of parsers to be applied to all API responses.
      
      You can add custom parsing using:
      
          responseTransformers.add(MyCustomTransformer())
          responseTransformers.add(MyCustomTransformer(), contentTypes: ["foo/bar"])
      
      By default, the transformer sequence includes JSON and plain text parsing. You can
      remove this default behavior by clearing the sequence:
      
          responseTransformers.clear()
    */
    public let responseTransformers: TransformerSequence = TransformerSequence()
    
    /// Default for `Resource.expirationTime`.
    public var defaultExpirationTime: NSTimeInterval = 300

    /// Default for `Resource.retryTime`.
    public var defaultRetryTime: NSTimeInterval = 1
    
    internal let transportProvider: TransportProvider
    private var resourceCache = WeakCache<String,Resource>()
    
    /**
      Creates a new service for the given API.
      
      Parameter: base The base URL of the API.
      Parameter: transportProvider A provider to use for networking. The default is Alamofire with its default
          configuration. You can pass an `AlamofireTransportProvider` created with a custom configuration,
          or provide your own networking implementation.
    */
    public init(
            base: String,
            transportProvider: TransportProvider = AlamofireTransportProvider())
        {
        self.baseURL = NSURL(string: base.URLString)?.alterPath
            {
            path in
            !path.hasSuffix("/")
                ? path + "/"
                : path
            }
        self.transportProvider = transportProvider
        
        responseTransformers.add(JsonTransformer(), contentTypes: ["*/json", "*/*+json"])
        responseTransformers.add(TextTransformer(), contentTypes: ["text/*"])
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
    }
