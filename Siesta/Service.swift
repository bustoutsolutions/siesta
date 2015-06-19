//
//  Service.swift
//  Siesta
//
//  Created by Paul on 2015/6/15.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Foundation

public class Service: NSObject
    {
    public let baseURL: NSURL?
    
    public init(baseURL: NSURL?)
        {
        self.baseURL = Service.normalizeBaseURL(baseURL)
        }

    public convenience init(base: String)
        {
        self.init(baseURL: NSURL(string: base))
        }
    
    public func resource(url: NSURL?) -> Resource
        {
        return Resource(service: self, url: url)
        }
    
    public func resource(path: String) -> Resource
        {
        return resource(baseURL?.URLByAppendingPathComponent(path))
        }
    
    private static func normalizeBaseURL(baseURL: NSURL?) -> NSURL?
        {
        guard let baseURL = baseURL,
                  components = NSURLComponents(URL: baseURL, resolvingAgainstBaseURL: true)
        else { return nil }
        
        if let path = components.path
        where path.hasSuffix("/")
            {
            components.path = path[path.startIndex ..< path.endIndex.predecessor()]
            }
            
        return components.URL
        }
    }
