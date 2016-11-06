//
//  PipelineProcessing.swift
//  Siesta
//
//  Created by Paul on 2016/8/7.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

internal extension Pipeline
    {
    private var stagesInOrder: [PipelineStage]
        { return order.flatMap { self[$0] } }

    private typealias StageAndEntry = (PipelineStage, CacheEntryProtocol?)

    private func stagesAndEntries(for resource: Resource) -> [StageAndEntry]
        {
        return stagesInOrder.map
            { stage in (stage, stage.cacheBox?.buildEntry(resource)) }
        }

    internal func makeProcessor(_ rawResponse: Response, resource: Resource) -> (Void) -> Response
        {
        // Generate cache keys on main thread (because this touches Resource)
        let stagesAndEntries = self.stagesAndEntries(for: resource)

        // Return deferred processor to run on background queue
        return
            {
            let result = Pipeline.processAndCache(rawResponse, using: stagesAndEntries)

            debugLog(.pipeline,       ["  └╴Response after pipeline:", result.summary()])
            debugLog(.networkDetails, ["    Details:", result.dump("      ")])

            return result
            }
        }

    // Runs on a background queue
    private static func processAndCache<StagesAndEntries: Collection>(
            _ rawResponse: Response,
            using stagesAndEntries: StagesAndEntries)
        -> Response
        where StagesAndEntries.Iterator.Element == StageAndEntry
        {
        return stagesAndEntries.reduce(rawResponse)
            {
            let input = $0,
                (stage, cacheEntry) = $1

            let output = stage.process(input)

            if case .success(let entity) = output,
               let cacheEntry = cacheEntry
                {
                debugLog(.cache, ["  ├╴Caching entity with", type(of: entity.content), "content in", cacheEntry])
                cacheEntry.write(entity)
                }

            return output
            }
        }

    internal func cachedEntity(for resource: Resource, onHit: @escaping (Entity<Any>) -> ())
        {
        // Extract cache keys on main thread
        let stagesAndEntries = self.stagesAndEntries(for: resource)

        defaultEntityCacheWorkQueue.async
            {
            if let entity = Pipeline.cacheLookup(using: stagesAndEntries)
                {
                DispatchQueue.main.async
                    { onHit(entity) }
                }
            }
        }

    // Runs on a background queue
    private static func cacheLookup(using stagesAndEntries: [StageAndEntry]) -> Entity<Any>?
        {
        for (index, (_, cacheEntry)) in stagesAndEntries.enumerated().reversed()
            {
            if let result = cacheEntry?.read()
                {
                debugLog(.cache, ["Cache hit for", cacheEntry])

                let processed = Pipeline.processAndCache(
                    .success(result),
                    using: stagesAndEntries.suffix(from: index + 1))

                switch processed
                    {
                    case .failure:
                        debugLog(.cache, ["Error processing cached entity; will ignore cached value. Error:", processed])

                    case .success(let entity):
                        return entity
                    }
                }
            }
        return nil
        }

    internal func updateCacheEntryTimestamps(_ timestamp: TimeInterval, for resource: Resource)
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
    fileprivate let buildEntry: (Resource) -> (CacheEntryProtocol?)
    internal let description: String

    init?<T: EntityCache>(cache: T?)
        {
        guard let cache = cache else { return nil }
        buildEntry = { CacheEntry(cache: cache, resource: $0) }
        description = String(describing: type(of: cache))
        }
    }

private protocol CacheEntryProtocol
    {
    func read() -> Entity<Any>?
    func write(_ entity: Entity<Any>)
    func updateTimestamp(_ timestamp: TimeInterval)
    func remove()
    }

private struct CacheEntry<Cache, Key>: CacheEntryProtocol
    where Cache: EntityCache, Cache.Key == Key
    {
    let cache: Cache
    let key: Key

    init?(cache: Cache, resource: Resource)
        {
        DispatchQueue.mainThreadPrecondition()

        guard let key = cache.key(for: resource) else { return nil }

        self.cache = cache
        self.key = key
        }

    func read() -> Entity<Any>?
        {
        return dispatchSyncOnWorkQueue
            { self.cache.readEntity(forKey: self.key) }
        }

    func write(_ entity: Entity<Any>)
        {
        cache.workQueue.async
            { self.cache.writeEntity(entity, forKey: self.key) }
        }

    func updateTimestamp(_ timestamp: TimeInterval)
        {
        cache.workQueue.async
            { self.cache.updateEntityTimestamp(timestamp, forKey: self.key) }
        }

    func remove()
        {
        cache.workQueue.async
            { self.cache.removeEntity(forKey: self.key) }
        }

    private func dispatchSyncOnWorkQueue<T>(_ action: (Void) -> T) -> T
        {
        var result: T?
        cache.workQueue.sync
            { result = action() }
        return result!
        }
    }
