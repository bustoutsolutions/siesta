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
        self.baseURL = alterURLPath(baseURL)
            {
            path in
            !path.hasSuffix("/")
                ? path + "/"
                : path
            }
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
