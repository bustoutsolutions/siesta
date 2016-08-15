//
//  RequestChain.swift
//  Siesta
//
//  Created by Paul on 2016/8/2.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

extension Request
    {
    /**
      Gathers multiple requests into a **request chain**, a wrapper that appears from the outside to be a single
      request. You can use this to automatically recover from failure conditions.

      The request chain starts
    */
    public func chained(whenCompleted callback: ResponseInfo -> RequestChainAction) -> Request
        { return RequestChain(wrapping: self, whenCompleted: callback) }
    }

public enum RequestChainAction
    {
    case PassTo(Request)
    case UseThisResponse
    case UseCustomResponse(ResponseInfo)
    }

internal final class RequestChain: RequestWithDefaultCallbacks
    {
    private let wrappedRequest: Request
    private let determineAction: ActionCallback
    private var responseCallbacks = CallbackGroup<ResponseInfo>()

    init(wrapping request: Request, whenCompleted determineAction: ActionCallback)
        {
        self.wrappedRequest = request
        self.determineAction = determineAction
        request.onCompletion(self.processResponse)
        }

    func addResponseCallback(callback: ResponseCallback) -> Self
        {
        responseCallbacks.addCallback(callback)
        return self
        }

    func processResponse(responseInfo: ResponseInfo)
        {
        switch determineAction(responseInfo)
            {
            case .UseThisResponse:
                responseCallbacks.notifyOfCompletion(responseInfo)

            case .UseCustomResponse(let customResponseInfo):
                responseCallbacks.notifyOfCompletion(customResponseInfo)

            case .PassTo(let request):
                request.onCompletion
                    { self.responseCallbacks.notifyOfCompletion($0) }
            }
        }

    typealias ActionCallback = ResponseInfo -> RequestChainAction

    var isCompleted: Bool
        {
        dispatch_assert_main_queue()
        return responseCallbacks.completedValue != nil
        }

    func cancel()
        { wrappedRequest.cancel() }

    func repeated() -> Request
        {
        return RequestChain(wrapping: wrappedRequest, whenCompleted: determineAction)
        }

    // MARK: Dummy implementaiton of progress (for now)

    var progress: Double { return 0 }

    func onProgress(callback: Double -> Void) -> Self
        { return self }
    }
