//
//  AlamoFire.Request+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Alamofire

internal class AlamofireSiestaRequest: Request, CustomDebugStringConvertible
    {
    private let resource: Resource
    internal weak var alamofireRequest: Alamofire.Request?
    
    private var response: Response?
    private var responseIsNewData: Bool = false
    
    init(resource: Resource, alamofireRequest: Alamofire.Request)
        {
        self.resource = resource
        self.alamofireRequest = alamofireRequest
        }
    
    func response(callback: AnyResponseCalback) -> Self
        {
        responseCallback
            {
            response, newData, nsresp in
            callback(response, nsresp)
            }
        return self
        }
    
    func success(callback: SuccessCallback) -> Self
        {
        responseCallback
            {
            response, newData, nsresp in
            if case .DATA(let data) = response
                { callback(data, nsresp) }
            }
        return self
        }
    
    func newData(callback: SuccessCallback) -> Self
        {
        responseCallback
            {
            response, newData, nsresp in
            if case .DATA(let data) = response where newData
                { callback(data, nsresp) }
            }
        return self
        }
    
    func notModified(callback: NotModifiedCallback) -> Self
        {
        responseCallback
            {
            response, newData, nsresp in
            if case .DATA = response where !newData
                { callback(nsresp) }
            }
        return self
        }
    
    func error(callback: ErrorCallback) -> Self
        {
        responseCallback
            {
            response, newData, nsresp in
            if case .ERROR(let error) = response
                { callback(error, nsresp) }
            }
        return self
        }
    
    func cancel()
        {
        alamofireRequest?.cancel()
        }
    
    private func responseCallback(callback: (Response, isNew: Bool, NSURLResponse?) -> Void)
        {
        alamofireRequest?.response
            {
            rawResp in
            
            // Crux of the whole thing here: only call processResponse the first time
            if let response = self.response
                { callback(response, isNew: self.responseIsNewData, rawResp.1) }
            else
                {
                let (resp, isNew) = processResponse(self.resource, rawResp)
                self.response = resp
                self.responseIsNewData = isNew
                callback(resp, isNew: isNew, rawResp.1)
                }
            }
        }

    var debugDescription: String
        {
        return "Siesta.Request:"
            + String(ObjectIdentifier(self).uintValue, radix: 16)
            + "("
            + debugStr([alamofireRequest?.request?.HTTPMethod, resource.url])
            + ")"
        }
    }

private func processResponse(resource: Resource, _ responseData: (NSURLRequest?, NSHTTPURLResponse?, AnyObject?, NSError?))
    -> (response: Response, newData: Bool)
    {
    let (_, nsres, payload, nserror) = responseData
    
    var response: Response
    var newData: Bool = true
    
    if nsres?.statusCode >= 400 || nserror != nil
        {
        response = .ERROR(Resource.Error(nsres, payload, nserror))
        }
    else if nsres?.statusCode == 304
        {
        if let data = resource.latestData
            {
            response = .DATA(data)
            newData = false
            }
        else
            {
            response = .ERROR(Resource.Error(
                userMessage: "No data",
                debugMessage: "Received HTTP 304, but resource has no existing data"))
            }
        }
    else if let payload = payload
        {
        response = .DATA(Resource.Data(nsres, payload))
        }
    else
        {
        response = .ERROR(Resource.Error(userMessage: "Empty response"))
        }
    
    debugLog(["Raw response:", response])
    response = resource.service.responseTransformers.process(response)
    
    return (response, newData)
    }


