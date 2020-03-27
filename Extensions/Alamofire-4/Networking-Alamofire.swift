//
//  Networking-Alamofire.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation
#if !COCOAPODS
    import Siesta
#endif
import Alamofire

/**
  Uses [Alamofire](https://github.com/Alamofire/Alamofire) for networking.

  You can create instances of this provider with a custom
  [Alamofire.Manager](http://cocoadocs.org/docsets/Alamofire/1.3.0/Classes/Manager.html)
  in order to control caching, certificate validation rules, etc. For example, here is a `Service` that will
  use a URLCache and will not use the cell network:

      class MyAPI: Service {
          init() {
              let configuration = URLSessionConfiguration.defaultSessionConfiguration()
              configuration.allowsCellularAccess = false
              super.init(
                  baseURL: "http://foo.bar/v1",
                  networking: AlamofireProvider(configuration: configuration))
          }
      }
*/
public struct AlamofireProvider: NetworkingProvider
    {
    public let manager: Alamofire.SessionManager

    public init(manager: Alamofire.SessionManager = SessionManager.default)
        { self.manager = manager }

    public init(configuration: URLSessionConfiguration)
        { self.init(manager: Alamofire.SessionManager(configuration: configuration)) }

    public func startRequest(
            _ request: URLRequest,
            completion: @escaping RequestNetworkingCompletionCallback)
        -> RequestNetworking
        {
        return AlamofireRequestNetworking(
            manager.request(request)
                .response { completion($0.response, $0.data, $0.error) })
        }
    }

internal struct AlamofireRequestNetworking: RequestNetworking, SessionTaskContainer
    {
    internal var alamofireRequest: Alamofire.Request

    init(_ alamofireRequest: Alamofire.Request)
        {
        self.alamofireRequest = alamofireRequest
        if let requestTask = alamofireRequest.task, case .suspended = requestTask.state
            {
            alamofireRequest.resume()   // in case manager.startRequestsImmediately is false
            }
        }

    var task: URLSessionTask
        {
        return alamofireRequest.task!
        }

    func cancel()
        { alamofireRequest.cancel() }
    }

extension Alamofire.SessionManager: NetworkingProviderConvertible
    {
    /// You can pass an `AlamoFire.Manager` when creating a `Service`.
    public var siestaNetworkingProvider: NetworkingProvider
        { return AlamofireProvider(manager: self) }
    }
