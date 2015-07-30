//
//  Transport.swift
//  Siesta
//
//  Created by Paul on 2015/7/30.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

public protocol TransportProvider
    {
    func transportForRequest(request: NSURLRequest) -> RequestTransport
    }

public protocol RequestTransport
    {
    func start(response: (nsres: NSHTTPURLResponse?, body: NSData?, nserror: NSError?) -> Void)
    func cancel()
    var isCancelled: Bool { get }
    }

