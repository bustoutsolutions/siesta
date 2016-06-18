//
//  Networking-Alamofire.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation
import Siesta
import Alamofire

/**
  Uses [Alamofire](https://github.com/Alamofire/Alamofire) for networking.

  You can create instances of this provider with a custom
  [Alamofire.Manager](http://cocoadocs.org/docsets/Alamofire/1.3.0/Classes/Manager.html)
  in order to control caching, certificate validation rules, etc. For example, here is a `Service` that will
  use an NSURLCache and will not use the cell network:

      class MyAPI: Service {
          init() {
              let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
              configuration.allowsCellularAccess = false
              super.init(
                  baseURL: "http://foo.bar/v1",
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
                .response
                    {
                    req, res, body, error in
                    completion(nsres: res, body: body, error: error)
                    })
        }
    }

internal struct AlamofireRequestNetworking: RequestNetworking, SessionTaskContainer
    {
    internal var alamofireRequest: Alamofire.Request

    init(_ alamofireRequest: Alamofire.Request)
        {
        self.alamofireRequest = alamofireRequest
        alamofireRequest.resume()   // in case manager.startRequestsImmediately is false
        }

    var task: NSURLSessionTask
        {
        return alamofireRequest.task
        }

    func cancel()
        { alamofireRequest.cancel() }
    }

extension Alamofire.Manager: NetworkingProviderConvertible
    {
    /// You can pass an `AlamoFire.Manager` when creating a `Service`.
    public var siestaNetworkingProvider: NetworkingProvider
        { return AlamofireProvider(manager: self) }
    }
