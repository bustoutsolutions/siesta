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
    // Configuration
    
    public let service: Service
    public let url: NSURL? // TODO: figure out what to do about invalid URLs
    
    // Request management
    
    public var loading: Bool { return !requests.isEmpty }
    public private(set) var requests = Set<Request>()
    
    // Resource state

    public private(set) var latestData: Data?
    public private(set) var latestError: Error?
    public var data: AnyObject? { return latestData?.payload }
    public var timestamp: NSTimeInterval
        {
        return max(
            latestData?.timestamp ?? 0,
            latestError?.timestamp ?? 0)
        }
    
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
    
    public func request(
            method:          Alamofire.Method,
            requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        let nsreq = NSMutableURLRequest(URL: url!)
        nsreq.HTTPMethod = method.rawValue
        requestMutation(nsreq)

        let request = service.sessionManager.request(nsreq)
        requests.insert(request)
        request.response
            {
            [weak self, weak request]
            _ in
            
            if let request = request
                { self?.requests.remove(request) }
            }
        return request
        }
    
    public func load() -> Request
        {
        return request(.GET)
                {
                nsreq in
                if let etag = self.latestData?.etag
                    { nsreq.setValue(etag, forHTTPHeaderField: "If-None-Match") }
                }
            .resourceResponse(self,
                success:     self.updateStateWithData,
                notModified: self.updateStateWithDataNotModified,
                error:       self.updateStateWithError)
        }
    
    private func updateStateWithData(data: Data)
        {
        self.latestError = nil
        self.latestData = data
        }

    private func updateStateWithDataNotModified()
        {
        self.latestError = nil
        self.latestData?.touch()
        }
    
    private func updateStateWithError(error: Error)
        {
        if let nserror = error.nsError
            where nserror.domain == "NSURLErrorDomain"
               && nserror.code == NSURLErrorCancelled
            { return }
        
        self.latestError = error
        }
    }
