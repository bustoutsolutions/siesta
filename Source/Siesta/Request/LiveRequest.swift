//
//  LiveRequest.swift
//  Siesta
//
//  Created by Paul on 2018/3/7.
//  Copyright © 2018 Bust Out Solutions. All rights reserved.
//
import Foundation

extension Resource
    {
    // MARK: Requests with Custom Logic
    /**
      Creates (but does **not** start) a new request using custom request logic.

      This method allows you to make a request using custom / external logic that does not use the service’s normal
      network provider. For example, you could use this to wrap a third-party OAUth library as a Siesta request, then
      use `Configuration.decorateRequests(...)` and `Request.chained(...)` to wait for OAuth before proceeding with the
      normal Siesta request.

      - SeeAlso: `RequestDelegate`
      - SeeAlso: `Request.start()`
      - SeeAlso: `Resource.hardWiredRequest(returning:)`
    */
    public static func prepareRequest(using delegate: RequestDelegate) -> Request
        {
        return LiveRequest(delegate: delegate)
        }
    }

/**
  Allows you to create `Request`s with custom logic. This is useful for taking things that are not standard network
  requests, and wrapping them so they look to Siesta as if they are. To create a custom request, pass your delegate to
  `Resource.prepareRequest(using:)`.

  You can also implement Siesta’s `Request` protocol yourself, but this is a daunting task full of pitfalls and
  redundant effort. This protocol provides customization points for only the things custom requests typically need to
  customize, and provides standard behavior and sanity checks. In particular, using `RequestDelegate`:

  - provides standard implementations for all the request hooks,
  - ensures those hooks are called _exactly_ once, even if your delegate misbehaves and reports multiple responses,
  - tracks request state and ensures valid state transitions,
  - polls request progress, and
  - handles cancellation cleanly, preventing “response after cancel” race conditions.

  Siesta itself uses this protocol to implement its own requests. Look at `NetworkRequestDelegate` and
  `RequestChainDelgate` in Siesta’s source code for examples of implementing this protocol.

  - SeeAlso: `Resource.prepareRequest(using:)`
*/
public protocol RequestDelegate
    {
    /**
      The delegate should commence the operation (e.g. network call) that will eventually produce a response.

      Siesta will call this method at most once per call to `Resource.prepareRequest(using:)`.

      Implementations of this method MUST eventually call `completionHandler.broadcastResponse(...)`. They will
      typically want to hold on to the `completionHandler` for the duration of a long-running operation in order to
      broadcast the response at the end.
    */
    func startUnderlyingOperation(passingResponseTo completionHandler: RequestCompletionHandler)

    /**
      Indicates that the `Request` using this delegate has been cancelled, and the delegate MAY cancel its underlying
      operation as well.
    */
    func cancelUnderlyingOperation()

    /**
      Returns another delegate which would perform the same underlying operation as this one. What consitutes the “same
      operation” is delegate-specific; for example, the new delegate may re-read relevant resource configuration.

      If you never use `Request.repeated()`, you can decline to implement this by calling `fatalError()`.
    */
    func repeated() -> RequestDelegate

    /**
      Asks your delegate to report progress ranging from 0 to 1. Implementations may be as accurate or as inaccurate
      as they wish. Values returned by this method SHOULD increase monotonically.

      Siesta will ensure that a `Request` reports progress of 1 when completed, regardless of what this method returns.
    */
    func computeProgress() -> Double

    /**
      The time interval at which you would like your `computeProgress()` method to be called.
    */
    var progressReportingInterval: TimeInterval { get }

    /**
      A description of the underlying operation suitable for logging and debugging.
    */
    var requestDescription: String { get }
    }

extension RequestDelegate
    {
    /**
      Returns a constant 0.
    */
    public func computeProgress() -> Double
        { return 0 }

    /**
      1/20th of a second.
    */
    public var progressReportingInterval: TimeInterval
        { return 0.05 }
    }

/**
  Provides callbacks for a `RequestDelegate` to use once its underlying operation is complete and it has response data
  to report.

  - SeeAlso: `RequestDelegate.startUnderlyingOperation(completionHandler:)`
*/
public protocol RequestCompletionHandler
    {
    /**
      Indicates that the `RequestDelegate`’s underlying operation has produced a response, and the request is thus
      complete. `RequestDelegate`s MUST eventually call this method _at least_ once after the call to
      `RequestDelegate.startUnderlyingOperation(...)`, and SHOULD call it _exactly_ once.

      - Note:
          The `Request` will pass this data on to the request hooks exactly as is. The pipeline only applies to standard
          network requests.

      - Note:
          Siesta only uses the response data from the first call to this method. You may call this method multiple
          times, but Siesta will ignore all subsequent calls.
    */
    func broadcastResponse(_ newInfo: ResponseInfo)

    /**
      Indicates whether Siesta would ignore the given response info if it were passed to `broadcastResponse(_:)`.

      `RequestDelegate`s SHOULD use this to avoid doing unnecessary post-processing or follow-up operations after
      the underlying operation has produced a response.
    */
    func willIgnore(_ responseInfo: ResponseInfo) -> Bool
    }

private final class LiveRequest: Request, RequestCompletionHandler, CustomDebugStringConvertible
    {
    private let delegate: RequestDelegate
    private var responseCallbacks = CallbackGroup<ResponseInfo>()
    private var progressTracker = ProgressTracker()
    private var underlyingOperationStarted = false

    init(delegate: RequestDelegate)
        {
        self.delegate = delegate
        }

    @discardableResult
    final func start() -> Request
        {
        DispatchQueue.mainThreadPrecondition()

        guard state == .notStarted else
            {
            SiestaLog.log(.networkDetails, [delegate.requestDescription, "already started"])
            return self
            }

        SiestaLog.log(.network, [delegate.requestDescription])

        underlyingOperationStarted = true
        delegate.startUnderlyingOperation(passingResponseTo: self)

        progressTracker.start(
            progressProvider: delegate.computeProgress,
            reportingInterval: delegate.progressReportingInterval)

        return self
        }

    final func cancel()
        {
        DispatchQueue.mainThreadPrecondition()

        guard state != .completed else
            {
            SiestaLog.log(.network, ["cancel() called but request already completed:", delegate.requestDescription])
            return
            }

        SiestaLog.log(.network, ["Cancelled", delegate.requestDescription])

        delegate.cancelUnderlyingOperation()

        broadcastResponse(.cancellation)
        }

    func onProgress(_ callback: @escaping (Double) -> Void) -> Request
        {
        progressTracker.callbacks.addCallback(callback)
        return self
        }

    var progress: Double
        { return progressTracker.progress }

    final func onCompletion(_ callback: @escaping (ResponseInfo) -> Void) -> Request
        {
        responseCallbacks.addCallback(callback)
        return self
        }

    final var state: RequestState
        {
        DispatchQueue.mainThreadPrecondition()

        if responseCallbacks.completedValue != nil
            { return .completed }
        else if underlyingOperationStarted
            { return .inProgress }
        else
            { return .notStarted }
        }

    final func willIgnore(_ responseInfo: ResponseInfo) -> Bool
        {
        let newResponse = responseInfo.response

        guard let existingResponse = responseCallbacks.completedValue?.response else
            { return false }

        // We already received a response; don't broadcast another one.

        if !existingResponse.isCancellation
            {
            SiestaLog.log(.network,
                [
                "WARNING: Received response for request that was already completed:", delegate.requestDescription,
                "This may indicate a bug in your NetworkingProvider, your custom RequestDelegate, or Siesta itself.",
                "If it is the latter, please file a bug report: https://github.com/bustoutsolutions/siesta/issues/new",
                "\n    Previously received:", existingResponse,
                "\n    New response:", newResponse
                ])
            }
        else if !newResponse.isCancellation
            {
            // Sometimes the network layer sends a cancellation error. That’s not of interest if we already knew
            // we were cancelled. If we received any other response after cancellation, log that we ignored it.

            SiestaLog.log(.networkDetails,
                [
                "Received response, but request was already cancelled:", delegate.requestDescription,
                "\n    New response:", newResponse
                ])
            }

        return true
        }

    final func broadcastResponse(_ newInfo: ResponseInfo)
        {
        DispatchQueue.mainThreadPrecondition()

        if willIgnore(newInfo)
            { return }

        progressTracker.complete()

        responseCallbacks.notifyOfCompletion(newInfo)
        }

    func repeated() -> Request
        {
        return Resource.prepareRequest(using: delegate.repeated())
        }

    // MARK: Debug

    final var debugDescription: String
        {
        return "Request:"
            + String(UInt(bitPattern: ObjectIdentifier(self)), radix: 16)
            + "("
            + delegate.requestDescription
            + ")"
        }
    }
