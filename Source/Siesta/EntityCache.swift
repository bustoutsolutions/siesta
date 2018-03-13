//
//  EntityCache.swift
//  Siesta
//
//  Created by Paul on 2015/8/24.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/**
  A strategy for saving entities between runs of the app. Allows apps to:

  - launch with the UI in a valid and populated (though possibly stale) state,
  - recover from low memory situations with fewer reissued network requests, and
  - work offline.

  Siesta can aldo use whatever HTTP request the networking layer provides (e.g. `URLCache`). Why another type of
  caching, then? Because `URLCache` has a several subtle but significant mismatches with the use cases above.

  The big one:

  * The purpose of HTTP caching is to _prevent_ network requests, but what we need is a way to show old data _while
    issuing new requests_. This is the real deal-killer.

  Additionally, but less crucially:

  * HTTP caching is [complex](http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html), and was designed around a set of
    goals relating to static assets and shared proxy caches — goals that look very different from reinflating Siesta
    resources’ in-memory state. It’s difficult to guarantee that `URLCache` interacting with the HTTP spec will
    exhibit the behavior we want; the logic involved is far more tangled and brittle than implementing a separate cache.
  * Precisely because of the complexity of these rules, APIs frequently disable all caching via headers.
  * HTTP caching does not preserve Siesta’s timestamps, which thwarts the staleness logic.
  * HTTP caching stores raw responses. Apps may wish instead to cache responses in an app-specific parsed form.

  Siesta currently does not include any implementations of `EntityCache`, but a future version will.

  - Warning: Siesta calls `EntityCache` methods on a GCD background queue, so your implementation **must be
             thread-safe**.

  - SeeAlso: `PipelineStage.cacheUsing(_:)`
*/
public protocol EntityCache
    {
    /**
      The type this cache uses to look up cache entries. The structure of keys is entirely up to the cache, and is
      opaque to Siesta.
    */
    associatedtype Key

    /**
      The type of payload this cache knows how to store and retrieve. If the response data configured at a particular
      point in the cache does not match this content type, Siesta will log a warning and bypass the cache.
    */
    associatedtype ContentType

    /**
      Provides the key appropriate to this cache for the given resource.

      A cache may opt out of handling the given resource by returning nil.

      This method is called for both cache writes _and_ for cache reads. The `resource` therefore may not have
      any content. Implementations will almost always examine `resource.url`. (Cache keys should be _at least_ as unique
      as URLs except in very unusual circumstances.)

      - Warning: When working with an authenticated API, caches must take care not to accidentally mix cached responses
                 for different users. The usual solution to this is to make `Key` vary with some sort of user ID as
                 well as the URL.

      - Note: This method is always called on the **main thread**. However, the key it returns will be passed repeatedly
              across threads. Siesta therefore strongly recommends making `Key` a value type, i.e. a struct.
    */
    func key(for resource: Resource) -> Key?

    /**
      Return the entity associated with the given key, or nil if it is not in the cache.

      If this method returns an entity, it passes through the portion of the transformer pipeline _after_ this cache.

      - Warning: This method may be called on a background thread. Make sure your implementation is threadsafe.
    */
    func readEntity(forKey key: Key) throws -> Entity<ContentType>?

    /**
      Store the given entity in the cache, associated with the given key.

      This method receives entities _after_ they have been through the stage of the transformer pipeline for which this
      cache is configured.

      Implementations are under no obligation to actually perform the write. This method can — and should — examine the
      type of the entity’s `content` and/or its header values, and ignore it if it is unencodable or otherwise
      unsuitable for caching.

      Note that this method does not receive a URL as input; if you need to limit caching to specific resources, use
      Siesta’s configuration mechanism to control which resources are cacheable.

      - Warning: The method may be called on a background thread. Make sure your implementation is threadsafe.
    */
    func writeEntity(_ entity: Entity<ContentType>, forKey key: Key) throws

    /**
      Update the timestamp of the entity for the given key. If there is no such cache entry, do nothing.
    */
    func updateEntityTimestamp(_ timestamp: TimeInterval, forKey key: Key) throws

    /**
      Remove any entities cached for the given key. After a call to `removeEntity(forKey:)`, subsequent calls to
      `readEntity(forKey:)` for the same key **must** return nil until the next call to `writeEntity(_:forKey:)`.
    */
    func removeEntity(forKey key: Key) throws

    /**
      Returns the GCD queue on which this cache implementation will do its work.
    */
    var workQueue: DispatchQueue { get }
    }

internal var defaultEntityCacheWorkQueue: DispatchQueue =
    DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated)

extension EntityCache
    {
    /// Returns a concurrent queue with priority `QOS_CLASS_USER_INITIATED`.
    public var workQueue: DispatchQueue
        { return defaultEntityCacheWorkQueue }
    }

extension EntityCache
    {
    /**
      Reads the entity from the cache, updates its timestamp, then writes it back.

      While this default implementation always gives the correct behavior, cache implementations may choose to override
      it for performance reasons.
    */
    public func updateEntityTimestamp(_ timestamp: TimeInterval, forKey key: Key) throws
        {
        guard var entity = try readEntity(forKey: key) else
            { return }
        entity.timestamp = timestamp
        try writeEntity(entity, forKey: key)
        }
    }
