//
//  PersistentCache.swift
//  Siesta
//
//  Created by Paul on 2015/8/24.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

/**
  A strategy for saving entities between runs of the app. Allows apps to:

  - launch with the UI in a valid and populated (though possibly stale) state,
  - recover from low memory situations with fewer reissued network requests, and
  - work offline.

  Siesta uses any HTTP request caching provided by the networking layer (e.g. `NSURLCache`). Why another type of
  caching, then? Because `NSURLCache` has a subtle but significant mismatch with the use cases above:

  * The purpose of HTTP caching is to _prevent_ network requests, but what we need is a way to show old data _while
    issuing new requests_. This is the real deal-killer.

  Additionally, but less crucially:

  * HTTP caching is [complex](http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html), and was designed around a set of
    goals relating to static assets and shared proxy caches — goals that look very different from reinflating Siesta
    resources’ in-memory state. It’s difficult to guarantee that `NSURLCache` interacting with the HTTP spec will
    exhibit the behavior we want; the logic involved is far more tangled and brittle than implementing a separate cache.
  * Precisely because of the complexity of these rules, APIs frequently disable all caching via headers.
  * HTTP caching does not preserve Siesta’s timestamps, which thwarts the staleness logic.
  * HTTP caching stores raw responses; storing parsed responses offers the opportunity for faster app launch.

  Siesta currently does not include any implementations of `EntityCache`, but a future version will.

  - Warning: Siesta calls `EntityCache` methods on a GCD background queue, so your implementation **must be
             thread-safe**.

  - SeeAlso: `Configuration.persistentCache`
*/
public protocol EntityCache
    {
    /**
      Return the entity associated with the given key, or nil if it is not in the cache.

      If this method returns an entity, it does _not_ pass through the transformer pipeline. Implementations should
      return the entity as if already fully parsed and transformed — with the same type of `entity.content` that was
      originally sent to `writeEntity(...)`.

      - Warning: This method may be called on a background thread. Make sure your implementation is threadsafe.
    */
    func readEntity(forKey key: String) -> Entity?

    /**
      Store the given entity in the cache, associated with the given key. The key’s format is arbitrary, and internal
      to Siesta. (OK, it’s just the resource’s URL, but you should pretend you don’t know that in your implementation.
      Cache implementations should treat the `forKey` parameter as an opaque value.)

      This method receives entities _after_ they have been through the transformer pipeline. The `entity.content` will
      be a parsed object, not raw data.

      Implementations are under no obligation to actually perform the write. This method can — and should — examine the
      type of the entity’s `content` and/or its header values, and ignore it if it is not encodable.

      Note that this method does not receive a URL as input; if you need to limit caching to specific resources, use
      Siesta’s configuration mechanism to control which resources are cacheable.

      - Warning: The method may be called on a background thread. Make sure your implementation is threadsafe.
    */
    func writeEntity(entity: Entity, forKey key: String)
    }


/**
  A strategy for transforming `Entity` instances to and from raw byte data.

  Provided primarily to help `EntityCache` implementations.

  - Warning: When used with an `EntityCache`, these methods will run on a GCD background queue, so your implementation
             **must be thread-safe**.
*/
public protocol EntityEncoder
    {
    /// Returns entity, including all of its metadata, serialized as raw data. Returns nil if this encoder does not know
    /// how to encode the entity.
    func encodeEntity(entity: Entity) -> NSData?

    /// Decodes the data as an entity. Returns nil if the decoding fails for any reason.
    func decodeEntity(data: NSData) -> Entity?
    }

/**
  Encodes `Entity` instances with JSON content for storage.

  Do not confuse this class with `JSONResponseTransformer`. They have different purposes:

  - `JSONResponseTransformer`: HTTP response ⟶ `Entity` or `Error`
  - `JSONEntityEncoder`: `Entity` ↔ persistent storage
*/
public struct JSONEntityEncoder: EntityEncoder
    {
    /// :nodoc:
    public init() { }

    /// Encodes the entity iff its `content` is a valid JSON object.
    public func encodeEntity(entity: Entity) -> NSData?
        {
        guard let obj = entity.content as? AnyObject where NSJSONSerialization.isValidJSONObject(obj) else
            { return nil }

        let json = NSMutableDictionary()
        json["content"]   = obj
        json["headers"]   = entity.headers
        json["charset"]   = entity.charset
        json["timestamp"] = entity.timestamp

        return try? NSJSONSerialization.dataWithJSONObject(json, options: [])
        }

    /// Decodes an entity with JSON content.
    public func decodeEntity(data: NSData) -> Entity?
        {
        let decoded: AnyObject
        do { decoded = try NSJSONSerialization.JSONObjectWithData(data, options: []) }
        catch { return nil }

        guard let json = decoded as? NSDictionary,
                  content   = json["content"],
                  headers   = json["headers"] as? [String:String],
                  timestamp = json["timestamp"] as? NSTimeInterval
        else { return nil }

        let charset = json["charset"] as? String  // can be nil

        return Entity(content: content, charset: charset, headers: headers, timestamp: timestamp)
        }
    }
