//
//  Request.swift
//  Siesta
//
//  Created by Paul on 2015/7/20.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/**
  HTTP request methods.

  See the various `Resource.request(...)` methods.
*/
public enum RequestMethod: String
    {
    /// OPTIONS
    case options

    /// GET
    case get

    /// HEAD. The HTTP method, not the body part.
    case head

    /// POST. Just POST. Doc comment is the same as the enum.
    case post

    /// So you’re really reading the docs for all these, huh?
    case put

    /// OK then, I’ll reward your diligence. Or punish it, depending on your level of refinement.
    ///
    /// What’s the difference between a poorly maintained Greyhound terminal and a lobster with breast implants?
    case patch

    /// One’s a crusty bus station, and the other’s a busty crustacean.
    ///
    /// I’m here all week! Thank you for reading the documentation!
    case delete

    internal static let all: [RequestMethod] = [.get, .post, .put, .patch, .delete, .head, .options]
    }

/**
  An API request. Provides notification hooks about the status of the request, and allows cancellation.

  Note that this represents only a _single request_, whereas `ResourceObserver`s receive notifications about
  _all_ resource load requests, no matter who initiated them. Note also that these hooks are available for _all_
  requests, whereas `ResourceObserver`s only receive notifications about changes triggered by `load()`, `loadIfNeeded()`,
  and `overrideLocalData(...)`.

  `Request` guarantees that it will call any given callback _at most_ one time.

  Callbacks are always called on the main thread.

  - Note:
      There is no race condition between a callback being added and a response arriving. If you add a callback after the
      response has already arrived, the callback is still called as usual. In other words, when attaching a hook, you
      **do not need to worry** about where the request is in its lifecycle. Except for how soon it’s called, your hook
      will see the same behavior regardless of whether the request has not started yet, is in progress, or is completed.
*/
public protocol Request: class
    {
    /**
      Call the closure once when the request finishes for any reason.
    */
    @discardableResult
    func onCompletion(_ callback: @escaping (ResponseInfo) -> Void) -> Self

    /// Call the closure once if the request succeeds.
    @discardableResult
    func onSuccess(_ callback: @escaping (Entity<Any>) -> Void) -> Self

    /// Call the closure once if the request succeeds and the data changed.
    @discardableResult
    func onNewData(_ callback: @escaping (Entity<Any>) -> Void) -> Self

    /// Call the closure once if the request succeeds with a 304.
    @discardableResult
    func onNotModified(_ callback: @escaping (Void) -> Void) -> Self

    /// Call the closure once if the request fails for any reason.
    @discardableResult
    func onFailure(_ callback: @escaping (RequestError) -> Void) -> Self

    /**
      Immediately start this request if it was deferred. Does nothing if the request is already started.

      You rarely need to call this method directly, because most requests are started for you automatically:

      - Any request you receive from `Resource.request(...)` or `Resource.load()` is already started.
      - Requests start automatically when you use `RequestChainAction.passTo` in a chain.

      When do you need this method, then? It’s rare. There are two situations:

      - `Configuration.decorateRequests(...)` can defer a request by hanging on to it while returning a different request.
        You can use this method to manually start a request that was deferred this way.
      - `Request.repeated()` does not automatically start the request it returns. This is to allow you to implement
        time-delayed retries.
    */
    @discardableResult
    func start() -> Self

    /**
      True if the request has received and handled a server response, encountered a pre-request client-side side error,
      or been cancelled.
    */
    var isCompleted: Bool { get }

    /**
      An estimate of the progress of the request, taking into account request transfer, response transfer, and latency.
      Result is either in [0...1], or is NAN if insufficient information is available.

      The property will always be 1 if a request is completed. Note that the converse is not true: a value of 1 does
      not necessarily mean the request is completed; it means only that we estimate the request _should_ be completed
      by now. Use the `isCompleted` property to test for actual completion.
    */
    var progress: Double { get }

    /**
      Call the given closure with progress updates at regular intervals while the request is in progress.
      Will _always_ receive a call with a value of 1 when the request completes.
    */
    @discardableResult
    func onProgress(_ callback: @escaping (Double) -> Void) -> Self

    /**
      Cancel the request if it is still in progress. Has no effect if a response has already been received.

      If this method is called while the request is in progress, it immediately triggers the `failure`/`completion`
      callbacks, with the error’s `cause` set to `RequestError.Cause.RequestCancelled`.

      Note that `cancel()` is not guaranteed to stop the request from reaching the server. In fact, it is not guaranteed
      to have any effect at all on the underlying request, subject to the whims of the `NetworkingProvider`. Therefore,
      after calling this method on a mutating request (POST, PUT, etc.), you should consider the service-side state of
      the resource to be unknown. Is it safest to immediately call either `Resource.load()` or `Resource.wipe()`.

      This method _does_ guarantee, however, that after it is called, even if a network response does arrive it will be
      ignored and not trigger any callbacks.
    */
    func cancel()

    /**
      Send the same request again, returning a new `Request` instance for the new attempt.

      The return request is not already started. You must call `start()` when you are ready for it to begin.

      - Warning:
          Use with caution! Repeating a failed request for any HTTP method other than GET is potentially unsafe,
          because you do not always know whether the server processed your request before the error occurred. **Ensure
          that it is safe to repeat a request before calling this method.**

      This method picks up certain contextual changes:

      - It **will** honor any changes to `Configuration.headers` made since the original request.
      - It **will** rerun the `requestMutation` closure you passed to `Resource.request(...)` (if you passed one).
      - It **will not** redecorate the request, and **will not** pick up any changes to
        `Configuration.decorateRequests(...)` since the original call. This is so that a request wrapper can safely
        retry its nested request without triggering a brain-bending hall of mirrors effect.

      Note that this means the new request may not be indentical to the original one.

      - Warning:
          Because `repeated()` will pick up header changes from configuration, it is possible for a request to run
          again with different auth credentials. This is intentional: one of the primary use cases for this dangerous
          method is automatically retrying a request with an updated auth token. However, the onus is on you to ensure
          that you do not hold on to and repeat a request after a user logs out. Put those safety goggles on.

      - Note:
          The new `Request` does **not** attach all the callbacks (e.g. `onCompletion(_:)`) from the old one.
          Doing so would violate the API contract of `Request` that any callback will be called at most once.

          After calling `repeated()`, you will need to attach new callbacks to the new request. Otherwise nobody will
          hear about the response when it arrives. (Q: If a request completes and nobody’s around to hear it, does it
          make a response? A: Yes, because it still uses bandwidth.)

          By the same principle, repeating a `load()` request will trigger a second network call, but will not cause the
          resource’s state to be updated again with the result.
    */
    func repeated() -> Request
    }

/**
  The outcome of a network request: either success (with an entity representing the resource’s current state), or
  failure (with an error).
*/
public enum Response: CustomStringConvertible
    {
    /// The request succeeded, and returned the given entity.
    case success(Entity<Any>)

    /// The request failed because of the given error.
    case failure(RequestError)

    /// True if this is a cancellation response
    public var isCancellation: Bool
        {
        if case .failure(let error) = self
            { return error.cause is RequestError.Cause.RequestCancelled }
        else
            { return false }
        }

    /// :nodoc:
    public var description: String
        {
        switch self
            {
            case .success(let value): return debugStr(value)
            case .failure(let value): return debugStr(value)
            }
        }
    }

/// A `Response`, plus metadata about the nature of the response.
public struct ResponseInfo
    {
    /// The result of a `Request`.
    public var response: Response

    /// Indicates whether `response` is newly received data, or a previous response reused.
    /// Used to distinguish `ResourceEvent.newData` from `ResourceEvent.notModified`.
    public var isNew: Bool

    /// Creates new responseInfo, with `isNew` true by default.
    public init(response: Response, isNew: Bool = true)
        {
        self.response = response
        self.isNew = isNew
        }

    internal static let cancellation =
        ResponseInfo(
            response: .failure(RequestError(
                userMessage: NSLocalizedString("Request cancelled", comment: "userMessage"),
                cause: RequestError.Cause.RequestCancelled(networkError: nil))))
    }
