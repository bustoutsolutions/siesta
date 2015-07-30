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
        return AlamofireRequestTransport(request: request, sessionManager: sessionManager)
        }
    }

internal class AlamofireRequestTransport: RequestTransport
    {
    private var request: NSURLRequest
    private var sessionManager: Manager
    internal weak var alamofireRequest: Alamofire.Request?
    
    init(request: NSURLRequest, sessionManager: Manager)
        {
        self.request = request
        self.sessionManager = sessionManager
        }
    
    func start(response: (nsres: NSHTTPURLResponse?, body: NSData?, nserror: NSError?) -> Void)
        {
        assert(alamofireRequest == nil, "Already started")
        
        alamofireRequest = sessionManager.request(request)
            .response { response(nsres: $1, body: $2, nserror: $3) }
        }
    
    func cancel()
        {
        alamofireRequest?.cancel()
        isCancelled = true
        }

    private(set) var isCancelled: Bool = false
    }
