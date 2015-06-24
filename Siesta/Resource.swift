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

    public private(set) var state: State
    public var data: AnyObject? { return state.latestData?.payload }
    
    init(service: Service, url: NSURL?)
        {
        self.service = service
        self.url = url?.absoluteURL
        self.state = State()
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
            _ in
            
            if let request = request
                { self?.requests.remove(request) }
            }
        return request
        }
    
    public func load() -> Request
        {
        return request(.GET).response
            {
            [weak self]
            nsreq, nsres, data, error in
            
            if let data = data
                where error == nil
                {
                self?.updateStateWithData(data, response: nsres)
                }
            else
                {
                self?.updateStateWithError(error, response: nsres)
                }
            }
        }
    
    private func updateStateWithData(data: AnyObject, response: NSHTTPURLResponse?)
        {
        func header(key: String) -> String?
            { return response?.allHeaderFields[key] as? String }
        
        var newState = self.state
        newState.latestError = nil
        newState.latestData = Data(
            payload:  data,
            mimeType: header("Content-Type") ?? "application/octet-stream",
            etag:     header("ETag"))
        self.state = newState
        }
    
    private func updateStateWithError(error: NSError?, response: NSHTTPURLResponse?)
        {
        var newState = self.state
        newState.latestError = Error()
        self.state = newState
        }
    
    public struct State
        {
        public var latestData: Data?
        public var latestError: Error?

        public var timestamp: NSTimeInterval
            {
            return max(
                latestData?.timestamp ?? 0,
                latestError?.timestamp ?? 0)
            }
        }

    public struct Data
        {
        public var payload: AnyObject // TODO: Can result transformer + generics fix AnyObject?
                                      // Probably service-wide default data type + per-resource override that requires “as?”
        public var mimeType: String
        public var etag: String?
        public let timestamp: NSTimeInterval = NSDate.timeIntervalSinceReferenceDate()
        }

    public struct Error
        {
//        var nsError: String
//        var payload: AnyObject
        public let timestamp: NSTimeInterval = NSDate.timeIntervalSinceReferenceDate()
        }
    }

public func ==(lhs: Request, rhs: Request) -> Bool
    { return lhs === rhs }

extension Request: Hashable
    {
    public var hashValue: Int
        { return ObjectIdentifier(self).hashValue }
    }
