//
//  Service.swift
//  Siesta
//
//  Created by Paul on 2015/6/15.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Foundation
import Alamofire

public class Service: NSObject
    {
    public let baseURL: NSURL?
    public let sessionManager: Manager
    
    public let responseTransformers: TransformerSequence = TransformerSequence()
    
    public var defaultExpirationTime: NSTimeInterval = 300
    public var defaultRetryTime: NSTimeInterval = 10
    
    private var resourceCache = WeakCache<String,Resource>()
    
    public init(
            base: URLStringConvertible,
            sessionManager: Manager = Manager.sharedInstance)
        {
        self.baseURL = alterURLPath(NSURL(string: base.URLString))
            {
            path in
            !path.hasSuffix("/")
                ? path + "/"
                : path
            }
        self.sessionManager = sessionManager
        
        responseTransformers.add(JsonTransformer(), contentTypes: ["*/json", "*/*+json"])
        responseTransformers.add(TextTransformer(), contentTypes: ["text/*"])
        }
    
    public convenience init(base: URLStringConvertible, configuration: NSURLSessionConfiguration)
        {
        self.init(base: base, sessionManager: Manager(configuration: configuration))
        }
    
    public func resource(url: NSURL?) -> Resource
        {
        let key = url?.absoluteString ?? ""  // TODO: handle invalid URLs
        return resourceCache.get(key)
            {
            Resource(service: self, url: url)
            }
        }
    
    public func resource(path: String) -> Resource
        {
        return resource(baseURL?.URLByAppendingPathComponent(path.stripPrefix("/")))
        }
    }

private func alterURLPath(url: NSURL?, pathMutator: String -> String) -> NSURL?
    {
    guard let url = url,
              components = NSURLComponents(URL: url, resolvingAgainstBaseURL: true)
    else { return nil }
    
    let path = pathMutator(components.path ?? "")
    components.path = (path == "") ? nil : path
        
    return components.URL
    }
