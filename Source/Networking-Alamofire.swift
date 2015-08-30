//
//  Networking-Alamofire.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Alamofire

/**
  Uses [Alamofire](https://github.com/Alamofire/Alamofire) for networking.
  
  You can create instances of this class with a custom
  [Alamofire.Manager](http://cocoadocs.org/docsets/Alamofire/1.3.0/Classes/Manager.html)
  in order to control caching, certificate validation rules, etc. For example, here is a `Service` that will not cache
  anything and will not use the cell network:
  
      class MyAPI: Service {
          init() {
              let configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration()
              configuration.allowsCellularAccess = false
              super.init(
                  base: "http://foo.bar/v1",
                  networking: AlamofireProvider(configuration: configuration))
          }
      }
*/
public struct AlamofireProvider: NetworkingProvider
    {
    public let manager: Alamofire.Manager
    
    public init(manager: Alamofire.Manager = Manager.sharedInstance)
        { self.manager = manager }
    
    public init(configuration: NSURLSessionConfiguration)
        { self.init(manager: Alamofire.Manager(configuration: configuration)) }
    
    public func startRequest(
            request: NSURLRequest,
            completion: RequestNetworkingCompletionCallback)
        -> RequestNetworking
        {
        return AlamofireRequestNetworking(
            manager.request(request)
                .response { completion(nsres: $1, body: $2, nserror: $3) })
        }
    }

internal final class AlamofireRequestNetworking: RequestNetworking
    {
    internal var alamofireRequest: Alamofire.Request
    
    init(_ alamofireRequest: Alamofire.Request)
        {
        self.alamofireRequest = alamofireRequest
        alamofireRequest.resume()   // in case manager.startRequestsImmediately is false
        }
    
    func cancel()
        { alamofireRequest.cancel() }
    }

extension Alamofire.Manager: NetworkingProviderConvertible
    {
    public var siestaNetworkingProvider: NetworkingProvider
        { return AlamofireProvider(manager: self) }
    }
