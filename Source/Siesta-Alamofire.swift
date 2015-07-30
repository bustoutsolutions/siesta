//
//  AlamoFire.Request+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Alamofire

public class AlamofireTransportProvider: TransportProvider
    {
    public let sessionManager: Manager
    
    public init(sessionManager: Manager = Manager.sharedInstance)
        {
        self.sessionManager = sessionManager
        }
    
    public func startRequest(nsreq: NSURLRequest, resource: Resource) -> Request
        {
        return AlamofireSiestaRequest(
            resource: resource,
            alamofireRequest: sessionManager.request(nsreq))
        }
    }

internal class AlamofireSiestaRequest: AbstractRequest, CustomDebugStringConvertible
    {
    internal weak var alamofireRequest: Alamofire.Request?
    
    init(resource: Resource, alamofireRequest: Alamofire.Request)
        {
        super.init(resource: resource)
        
        self.alamofireRequest = alamofireRequest
        alamofireRequest.response(self.handleResponse)
        }
    
    override func cancel()
        {
        alamofireRequest?.cancel()
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
