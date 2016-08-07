//
//  Processing.swift
//  Siesta
//
//  Created by Paul on 2016/8/7.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

internal extension Pipeline
    {
    private var stagesInOrder: [PipelineStage]
        { return order.flatMap { stages[$0] } }

    private typealias StageAndEntry = (PipelineStage, CacheEntryProtocol?)

    private func stagesAndEntries(for resource: Resource) -> [StageAndEntry]
        {
        return stagesInOrder.map
            { stage in (stage, stage.cacheBox?.buildEntry(resource)) }
        }

    internal func makeProcessor(rawResponse: Response, resource: Resource) -> Void -> Response
        {
        // Generate cache keys on main queue (because this touches Resource)
        let stagesAndEntries = self.stagesAndEntries(for: resource)

        // Return deferred processor to run on background queue
        return { self.processAndCache(rawResponse, using: stagesAndEntries) }
        }

    private func processAndCache<StagesAndEntries: CollectionType where StagesAndEntries.Generator.Element == StageAndEntry>(
            rawResponse: Response,
            using stagesAndEntries: StagesAndEntries)
        -> Response
        {
        return stagesAndEntries.reduce(rawResponse)
            {
            let input = $0, (stage, cacheEntry) = $1

            let output = stage.process(input)

            if case .Success(let entity) = output
                {
                debugLog(.Cache, ["Caching entity with", entity.content.dynamicType, "content in", cacheEntry])
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0))
                    { cacheEntry?.write(entity) }
                }

            return output
            }
        }

    internal func cachedEntity(for resource: Resource, onHit: (Entity) -> ())
        {
        // Extract cache keys on main queue
        let stagesAndEntries = self.stagesAndEntries(for: resource)

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0))
            {
            if let entity = self.cacheLookup(using: stagesAndEntries)
                {
                dispatch_async(dispatch_get_main_queue())
                    { onHit(entity) }
                }
            }
        }

    private func cacheLookup(using stagesAndEntries: [StageAndEntry]) -> Entity?
        {
        for (index, (_, cacheEntry)) in stagesAndEntries.enumerate().reverse()
            {
            if let result = cacheEntry?.read()
                {
                debugLog(.Cache, ["Cache hit for", cacheEntry])

                let processed = processAndCache(
                    .Success(result),
                    using: stagesAndEntries.suffixFrom(index + 1))

                switch(processed)
                    {
                    case .Failure:
                        debugLog(.Cache, ["Error processing cached entity; will ignore cached value. Error:", processed])

                    case .Success(let entity):
                        return entity
                    }
                }
            }
        return nil
        }

    internal func updateCacheEntryTimestamps(timestamp: NSTimeInterval, for resource: Resource)
        {
        let stagesAndEntries = self.stagesAndEntries(for: resource)

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0))
            {
            for (_, cacheEntry) in stagesAndEntries
                { cacheEntry?.updateTimestamp(timestamp) }
            }
        }

    internal func removeCacheEntries(for resource: Resource)
        {
        let stagesAndEntries = self.stagesAndEntries(for: resource)

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0))
            {
            for (_, cacheEntry) in stagesAndEntries
                { cacheEntry?.remove() }
            }
        }
    }

// MARK: Type erasure dance

internal struct CacheBox
    {
    private let buildEntry: (Resource) -> (CacheEntryProtocol?)

    init?<T: EntityCache>(cache: T?)
        {
        guard let cache = cache else { return nil }
        buildEntry = { CacheEntry(cache: cache, resource: $0) }
        }
    }

private protocol CacheEntryProtocol
    {
    func read() -> Entity?
    func write(entity: Entity)
    func updateTimestamp(timestamp: NSTimeInterval)
    func remove()
    }

private struct CacheEntry<Cache, Key where Cache: EntityCache, Cache.Key == Key>: CacheEntryProtocol
    {
    let cache: Cache
    let key: Key

    init?(cache: Cache, resource: Resource)
        {
        dispatch_assert_main_queue()

        guard let key = cache.key(for: resource) else { return nil }

        self.cache = cache
        self.key = key
        }

    func read() -> Entity?
        { return cache.readEntity(forKey: key) }

    func write(entity: Entity)
        { return cache.writeEntity(entity, forKey: key) }

    func updateTimestamp(timestamp: NSTimeInterval)
        { cache.updateEntityTimestamp(timestamp, forKey: key) }

    func remove()
        { cache.removeEntity(forKey: key) }
    }
