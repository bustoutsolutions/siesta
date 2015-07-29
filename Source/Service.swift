//
//  Service.swift
//  Siesta
//
//  Created by Paul on 2015/6/15.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Foundation

// TODO: Need prefix in Obj-C?
@objc(BOSService)
public class Service: NSObject
    {
    public let baseURL: NSURL?
    
    public let transportProvider: TransportProvider
    public let responseTransformers: TransformerSequence = TransformerSequence()
    
    public var defaultExpirationTime: NSTimeInterval = 300
    public var defaultRetryTime: NSTimeInterval = 10
    
    private var resourceCache = WeakCache<String,Resource>()
    
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
    
    @objc(resourceWithURL:)
    public func resource(url: NSURL?) -> Resource
        {
        let key = url?.absoluteString ?? ""  // TODO: handle invalid URLs
        return resourceCache.get(key)
            {
            Resource(service: self, url: url)
            }
        }
    
    @objc(resourceWithPath:)
    public func resource(path: String) -> Resource
        {
        return resource(baseURL?.URLByAppendingPathComponent(path.stripPrefix("/")))
        }
    }

public protocol TransportProvider
    {
    func buildRequest(nsreq: NSURLRequest, resource: Resource) -> Request
    }

