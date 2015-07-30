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
    
    public func buildRequest(nsreq: NSURLRequest, resource: Resource) -> Request
        {
        let alamoReq = sessionManager
            .request(nsreq)
            .response
                {
                nsreq, nsres, body, nserror in
                debugLog(.Network, [nsres?.statusCode, "←", nsreq?.HTTPMethod, nsreq?.URL])
                }
        return AlamofireSiestaRequest(resource: resource, alamofireRequest: alamoReq)
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
