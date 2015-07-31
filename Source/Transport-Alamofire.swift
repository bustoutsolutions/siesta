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
    
    public func transportForRequest(request: NSURLRequest) -> RequestTransport
        {
        sessionManager.startRequestsImmediately = false
        return AlamofireRequestTransport(sessionManager.request(request))
        }
    }

internal class AlamofireRequestTransport: RequestTransport
    {
    internal var alamofireRequest: Alamofire.Request
    private(set) var isCancelled: Bool = false
    
    init(_ alamofireRequest: Alamofire.Request)
        {
        self.alamofireRequest = alamofireRequest
        }
    
    func start(response: (nsres: NSHTTPURLResponse?, body: NSData?, nserror: NSError?) -> Void)
        {
        alamofireRequest
            .response { response(nsres: $1, body: $2, nserror: $3) }
            .resume()
        }
    
    func cancel()
        {
        alamofireRequest.cancel()
        isCancelled = true
        }
    }
