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
    /// GET
    case GET

    /// POST. Just POST. Doc comment is the same as the enum.
    case POST

    /// So you’re really reading the docs for all these, huh?
    case PUT

    /// OK then, I’ll reward your diligence. Or punish it, depending on your level of refinement.
    ///
    /// What’s the difference between a poorly maintained Greyhound terminal and a lobster with breast implants?
    case PATCH

    /// One’s a crusty bus station, and the other’s a busty crustacean.
    ///
    /// I’m here all week! Thank you for reading the documentation!
    case DELETE

    internal static let all: [RequestMethod] = [.GET, .POST, .PUT, .PATCH, .DELETE]
    }

/**
  An API request. Provides notification hooks about the status of the request, and allows cancellation.

  Note that this represents only a _single request_, whereas `ResourceObserver`s receive notifications about
  _all_ resource load requests, no matter who initiated them. Note also that these hooks are available for _all_
  requests, whereas `ResourceObserver`s only receive notifications about changes triggered by `load()`, `loadIfNeeded()`,
  and `overrideLocalData(_:)`.

  There is no race condition between a callback being added and a response arriving. If you add a callback after the
  response has already arrived, the callback is still called as usual.

  `Request` guarantees that it will call any given callback _at most_ one time.

  Callbacks are always called on the main thread.
*/
public protocol Request: class
    {
    /// Call the closure once when the request finishes for any reason.
    func onCompletion(callback: Response -> Void) -> Self

    /// Call the closure once if the request succeeds.
    func onSuccess(callback: Entity -> Void) -> Self

    /// Call the closure once if the request succeeds and the data changed.
    func onNewData(callback: Entity -> Void) -> Self

    /// Call the closure once if the request succeeds with a 304.
    func onNotModified(callback: Void -> Void) -> Self

    /// Call the closure once if the request fails for any reason.
    func onFailure(callback: Error -> Void) -> Self

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
    func onProgress(callback: Double -> Void) -> Self

    /**
      Cancel the request if it is still in progress. Has no effect if a response has already been received.

      If this method is called while the request is in progress, it immediately triggers the `failure`/`completion`
      callbacks, with the error’s `cause` set to `Error.Cause.RequestCancelled`.

      Note that `cancel()` is not guaranteed to stop the request from reaching the server. In fact, it is not guaranteed
      to have any effect at all on the underlying request, subject to the whims of the `NetworkingProvider`. Therefore,
      after calling this method on a mutating request (POST, PUT, etc.), you should consider the service-side state of
      the resource to be unknown. Is it safest to immediately call either `Resource.load()` or `Resource.wipe()`.

      This method _does_ guarantee, however, that after it is called, even if a network response does arrive it will be
      ignored and not trigger any callbacks.
    */
    func cancel()
    }

/**
  The outcome of a network request: either success (with an entity representing the resource’s current state), or
  failure (with an error).
*/
public enum Response: CustomStringConvertible
    {
    /// The request succeeded, and returned the given entity.
    case Success(Entity)

    /// The request failed because of the given error.
    case Failure(Error)

    /// True if this is a cancellation response
    public var isCancellation: Bool
        {
        if case .Failure(let error) = self
            { return error.cause is Error.Cause.RequestCancelled }
        else
            { return false }
        }

    /// :nodoc:
    public var description: String
        {
        switch self
            {
            case .Success(let value): return debugStr(value)
            case .Failure(let value): return debugStr(value)
            }
        }
    }
