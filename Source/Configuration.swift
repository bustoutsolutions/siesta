//
//  Configuration.swift
//  Siesta
//
//  Created by Paul on 2015/8/8.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

/**
  Options which control the behavior of a `Resource`.

  - SeeAlso: `Service.configure(...)`
*/
public struct Configuration
    {
    /**
      Time before valid data is considered stale by `Resource.loadIfNeeded()`.

      Defaults from `Service.defaultExpirationTime`, which defaults to 30 seconds.
    */
    public var expirationTime: NSTimeInterval = 30

    /**
      Time `Resource.loadIfNeeded()` will wait before allowing a retry after a failed request.

      Defaults from `Service.defaultRetryTime`, which defaults to 1 second.
    */
    public var retryTime: NSTimeInterval = 1

    /**
      Default request headers.
    */
    public var headers: [String:String] = [:]

    /**
      Adds a closure to be called after a `Request` is created, but before it is started. Use this to add response
      hooks or cancel the request before sending.
    */
    public mutating func beforeStartingRequest(callback: (Resource, Request) -> Void)
        { beforeStartingRequestCallbacks.append(callback) }

    internal var beforeStartingRequestCallbacks: [(Resource, Request) -> Void] = []

    /**
      A sequence of parsers to be applied to responses.

      You can add custom parsing using:

          $0.config.responseTransformers.add(MyCustomTransformer())
          $0.config.responseTransformers.add(MyCustomTransformer(), contentTypes: ["foo/bar"])

      By default, the transformer sequence includes JSON, image, and plain text parsing. You can
      remove this default behavior by clearing the sequence:

          $0.config.responseTransformers.clear()

      - SeeAlso: `addContentTransformer`
    */
    public var responseTransformers: TransformerSequence = TransformerSequence()

    /**
      An optional store to maintain the state of resources between app launches.
    */
    public var persistentCache: EntityCache? = nil

    /**
      Interval at which request hooks & observers receive progress updates. This affects how frequently
      `Request.onProgress(_:)` and `ResourceObserver.resourceRequestProgress(_:progress:)` are called, and how often the
      `Request.progress` property (which is partially time-based) is updated.
    */
    public var progressReportingInterval: NSTimeInterval = 0.05

    /**
      Holds a mutable configuration while closures passed to `Service.configure(...)` modify it.

      The reason that method doesn’t just accept a closure with an `inout` param is that doing so requires a messy
      flavor of closure declaration that makes the API much harder to use:

          configure("/things/​*") { (inout config: Configuration) in config.retryTime = 1 }

      This wrapper class allows usage to instead look like:

          configure("/things/​*") { $0.config.retryTime = 1 }
    */
    public final class Builder
        {
        /// Mutable for modification while building a resource’s config.
        public var config: Configuration = Configuration()
        }
    }
