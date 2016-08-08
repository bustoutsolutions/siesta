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
        // Generate cache keys on main thread (because this touches Resource)
        let stagesAndEntries = self.stagesAndEntries(for: resource)

        // Return deferred processor to run on background queue
        return { self.processAndCache(rawResponse, using: stagesAndEntries) }
        }

    // Runs on a background queue
    private func processAndCache<StagesAndEntries: CollectionType where StagesAndEntries.Generator.Element == StageAndEntry>(
            rawResponse: Response,
            using stagesAndEntries: StagesAndEntries)
        -> Response
        {
        return stagesAndEntries.reduce(rawResponse)
            {
            let input = $0, (stage, cacheEntry) = $1

            let output = stage.process(input)

            if case .Success(let entity) = output,
               let cacheEntry = cacheEntry
                {
                debugLog(.Cache, ["Caching entity with", entity.content.dynamicType, "content in", cacheEntry])
                cacheEntry.write(entity)
                }

            return output
            }
        }

    internal func cachedEntity(for resource: Resource, onHit: (Entity) -> ())
        {
        // Extract cache keys on main thread
        let stagesAndEntries = self.stagesAndEntries(for: resource)

        dispatch_async(defaultEntityCacheWorkQueue)
            {
            if let entity = self.cacheLookup(using: stagesAndEntries)
                {
                dispatch_async(dispatch_get_main_queue())
                    { onHit(entity) }
                }
            }
        }

    // Runs on a background queue
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
        for (_, cacheEntry) in stagesAndEntries(for: resource)
            { cacheEntry?.updateTimestamp(timestamp) }
        }

    internal func removeCacheEntries(for resource: Resource)
        {
        for (_, cacheEntry) in stagesAndEntries(for: resource)
            { cacheEntry?.remove() }
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
        {
        return dispatchSyncOnWorkQueue
            { self.cache.readEntity(forKey: self.key) }
        }

    func write(entity: Entity)
        {
        dispatch_async(cache.workQueue)
            { self.cache.writeEntity(entity, forKey: self.key) }
        }

    func updateTimestamp(timestamp: NSTimeInterval)
        {
        dispatch_async(cache.workQueue)
            { self.cache.updateEntityTimestamp(timestamp, forKey: self.key) }
        }

    func remove()
        {
        dispatch_async(cache.workQueue)
            { self.cache.removeEntity(forKey: self.key) }
        }

    private func dispatchSyncOnWorkQueue<T>(action: (Void) -> T) -> T
        {
        if currentQueueIsWorkQueue
            { return action() }
        else
            {
            var result: T?
            dispatch_sync(cache.workQueue)
                { result = action() }
            return result!
            }
        }

    private var currentQueueIsWorkQueue: Bool
        {
        // This assumes that labels are unique. This is not absolutely guaranteed
        // to be a safe assumption; however, it is unlikely that a user will happen
        // to give their custom queue exactly the same name as the default work queue.

        return dispatch_queue_get_label(cache.workQueue)
            == dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL)
        }
    }
