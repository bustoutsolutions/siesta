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
      request. You can use this to add behavior to a request in a way that is transparent to outside observers. For
      example, you can transparently renew expired tokens.

      - Note: This returns a new `Request`, and does not alter the original one (thus `chained` and not `chain`). Any
          hooks attached to the original request will still see that request complete, and will not see any of the
          chaining behavior.

      In this pseudocode:

          let chainedRequest = underlyingRequest.chained {
            response in …whenCompleted…
          }

      …the following things happen, in this order:

      - The chain waits for `underlyingRequest` to complete.
      - The response (no matter whether success or failure) gets passed to `whenCompleted`.
      - The `whenCompleted` closure examines that `response`, and returns a `RequestChainAction`.
        - If it returns `.useResponse` or `.useThisResponse`, the chain is now done, and any hooks attached to
          `chainedRequest` see that response.
        - If it returns `.passTo(newRequest)`, then the chain will wait for `newRequest` (which may itself be a chain),
          and yield whatever repsonse it produces.

      Calling `cancel()` on `chainedRequest` cancels the currently executing request and immediately stops the chain,
      never executing your `whenCompleted` closure. (Note, however, that calling `cancel()` on `underlyingRequest`
      does _not_ stop the chain; instead, the cancellation error is passed to your `whenCompleted` just like any other error.)

      - Warning:
          This cancellation behavior means that your `whenCompleted` closure may never execute.
          If you want guaranteed execution of cleanup code, attach a handler to the chained request:

              let foo = ThingThatNeedsCleanup()
              request
                .chained { …some logic… }           // May not be called if chain is cancelled
                .onCompletion{ _ in foo.cleanUp() } // Guaranteed to be called exactly once

      Chained requests currently do not support progress. If you are reading these words and want that feature, please
      file an issue on Github!

      - SeeAlso: `Configuration.decorateRequests(...)`
    */
    public func chained(whenCompleted callback: @escaping (ResponseInfo) -> RequestChainAction) -> Request
        { return RequestChain(wrapping: self, whenCompleted: callback) }
    }

/**
  The possible actions a chained request may take after the underlying request completes.

  - See: `Request.chained(...)`
*/
public enum RequestChainAction
    {
    /// The chain will wait for the given request, and its response will become the chain’s response.
    case passTo(Request)

    /// The chain will end immediately with the given response.
    case useResponse(ResponseInfo)

    /// The chain will end immediately, passing through the response of the underlying request that just completed.
    case useThisResponse
    }

internal final class RequestChain: RequestWithDefaultCallbacks
    {
    private let wrappedRequest: Request
    private let determineAction: ActionCallback
    private var responseCallbacks = CallbackGroup<ResponseInfo>()
    private var isCancelled = false

    init(wrapping request: Request, whenCompleted determineAction: @escaping ActionCallback)
        {
        self.wrappedRequest = request
        self.determineAction = determineAction
        request.onCompletion(self.processResponse)
        }

    func addResponseCallback(_ callback: @escaping ResponseCallback) -> Self
        {
        responseCallbacks.addCallback(callback)
        return self
        }

    func processResponse(_ responseInfo: ResponseInfo)
        {
        guard !isCancelled else
            {
            return responseCallbacks.notifyOfCompletion(
                ResponseInfo.cancellation)
            }

        switch determineAction(responseInfo)
            {
            case .useThisResponse:
                responseCallbacks.notifyOfCompletion(responseInfo)

            case .useResponse(let customResponseInfo):
                responseCallbacks.notifyOfCompletion(customResponseInfo)

            case .passTo(let request):
                request.start()  // Necessary if we are passing to deferred original request
                request.onCompletion
                    { self.responseCallbacks.notifyOfCompletion($0) }
            }
        }

    typealias ActionCallback = (ResponseInfo) -> RequestChainAction

    func start() -> Self
        {
        wrappedRequest.start()
        return self
        }

    var isCompleted: Bool
        {
        DispatchQueue.mainThreadPrecondition()
        return responseCallbacks.completedValue != nil
        }

    func cancel()
        {
        isCancelled = true
        wrappedRequest.cancel()
        }

    func repeated() -> Request
        {
        return wrappedRequest.repeated().chained(whenCompleted: determineAction)
        }

    // MARK: Dummy implementaiton of progress (for now)

    var progress: Double { return 0 }

    func onProgress(_ callback: @escaping (Double) -> Void) -> Self
        { return self }
    }
