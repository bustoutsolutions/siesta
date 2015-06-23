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
    
    public var loading: Bool { return !requests.isEmpty }
    public private(set) var requests = Set<Request>()
    
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
        let request = service.sessionManager.request(method, url!)
        requests.insert(request)
        request.response
                {
                [weak self, weak request]
                nsreq, nsres, data, error in
                
                if let request = request
                    { self?.requests.remove(request) }
                }
        return request
        }
    
    }

public func ==(lhs: Request, rhs: Request) -> Bool
    { return lhs === rhs }

extension Request: Hashable
    {
    public var hashValue: Int
        { return ObjectIdentifier(self).hashValue }
    }
