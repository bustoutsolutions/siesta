//
//  Resource.swift
//  Siesta
//
//  Created by Paul on 2015/6/16.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Alamofire

public class Resource
    {
    public let service: Service
    public let url: NSURL? // TODO: figure out what to do about invalid URLs
    
    init(service: Service, url: NSURL?)
        {
        self.service = service
        self.url = url?.absoluteURL
        }
    
    public func child(path: String) -> Resource
        {
        return service.resource(url?.URLByAppendingPathComponent(path))
        }
    
    public func relative(path: String) -> Resource
        {
        return service.resource(NSURL(string: path, relativeToURL: url))
        }
    
    public func request(method: Alamofire.Method) -> Request
        {
        let req = service.sessionManager.request(method, url!).response
            { req, res, data, error in
            
            }
        return req
        }
    
    }
