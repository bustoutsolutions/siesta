//
//  PipelineProcessing.swift
//  Siesta
//
//  Created by Paul on 2016/8/7.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

extension Pipeline
    {
    private var stagesInOrder: [PipelineStage]
        { order.compactMap { self[$0] } }

    private typealias StageAndEntry = (PipelineStage, CacheEntryProtocol?)

    private func stagesAndEntries(for resource: Resource) -> [StageAndEntry]
        {
        stagesInOrder.map
            { stage in (stage, stage.cacheBox?.buildEntry(resource)) }
        }

    internal func makeProcessor(_ rawResponse: Response, resource: Resource) -> () -> ResponseInfo
        {
        // Generate cache keys on main thread (because this touches Resource)
        let stagesAndEntries = self.stagesAndEntries(for: resource)

        // Return deferred processor to run on background queue
        return
            {
            let result = Pipeline.process(rawResponse, using: stagesAndEntries)

            SiestaLog.log(.pipeline,       ["  └╴Response after pipeline:", result.response.summary()])
            SiestaLog.log(.networkDetails, ["    Details:", result.response.dump("      ")])

            return result
            }
        }

    // Runs on a background queue
    private static func process<StagesAndEntries: Collection>(
            _ rawResponse: Response,
            using stagesAndEntries: StagesAndEntries)
        -> ResponseInfo
        where StagesAndEntries.Iterator.Element == StageAndEntry
        {
        stagesAndEntries.reduce(into: ResponseInfo(response: rawResponse))
            {
            let (stage, cacheEntry) = $1

            $0.response = stage.process($0.response)

            if case .success(let entity) = $0.response,
               let cacheEntry = cacheEntry
                {
                $0.cacheActions.append(
                    {
                    SiestaLog.log(.cache, ["Caching entity with", type(of: entity.content), "content for", cacheEntry])
                    cacheEntry.write(entity)
                    })
                }
            }
        }

    internal func checkCache(for resource: Resource) -> Request
        {
        Resource
            .prepareRequest(using:
                CacheRequestDelegate(for: resource, searching: stagesAndEntries(for: resource)))
            .start()
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


// MARK: Cache Request

extension Pipeline
    {
    private struct CacheRequestDelegate: RequestDelegate
        {
        let requestDescription: String
        private let stagesAndEntries: [StageAndEntry]

        init(for resource: Resource, searching stagesAndEntries: [StageAndEntry])
            {
            requestDescription = "Cache request for \(resource)"
            self.stagesAndEntries = stagesAndEntries
            }

        func startUnderlyingOperation(passingResponseTo completionHandler: RequestCompletionHandler)
            {
            defaultEntityCacheWorkQueue.async
                {
                let response: Response
                if let entity = self.performCacheLookup()
                    { response = .success(entity) }
                else
                    {
                    response = .failure(RequestError(
                        userMessage: NSLocalizedString("Cache miss", comment: "userMessage"),
                        cause: RequestError.Cause.CacheMiss()))
                    }

                DispatchQueue.main.async
                    {
                    completionHandler.broadcastResponse(ResponseInfo(response: response))
                    }
                }
            }

        func cancelUnderlyingOperation()
            { }

        func repeated() -> RequestDelegate
            { self }

        // Runs on a background queue
        private func performCacheLookup() -> Entity<Any>?
            {
            for (index, (_, cacheEntry)) in stagesAndEntries.enumerated().reversed()
                {
                if let result = cacheEntry?.read()
                    {
                    SiestaLog.log(.cache, ["Cache hit for", cacheEntry])

                    let processed = Pipeline.process(
                        .success(result),
                        using: stagesAndEntries.suffix(from: index + 1))

                    switch processed.response
                        {
                        case .failure:
                            SiestaLog.log(.cache, ["Error processing cached entity; will ignore cached value. Error:", processed])

                        case .success(let entity):
                            return entity
                        }
                    }
                }
            return nil
            }
        }
    }


// MARK: Type erasure dance

internal struct CacheBox
    {
    fileprivate let buildEntry: (Resource) -> (CacheEntryProtocol?)
    internal let description: String

    init?<T: EntityCache>(cache: T?)
        {
        guard let cache = cache else
            { return nil }
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

private struct CacheEntry<Cache, Key>: CacheEntryProtocol, CustomStringConvertible
    where Cache: EntityCache, Cache.Key == Key
    {
    let cache: Cache
    let key: Key

    init?(cache: Cache, resource: Resource)
        {
        DispatchQueue.mainThreadPrecondition()

        guard let key = cache.key(for: resource) else
            { return nil }
        self.cache = cache
        self.key = key
        }

    func read() -> Entity<Any>?
        {
        cache.workQueue.sync
            {
            catchAndLogErrors(attemptingTo: "read cached entity")
                { try self.cache.readEntity(forKey: self.key)?.withContentRetyped() }
            }
        }

    func write(_ entity: Entity<Any>)
        {
        guard let cacheableEntity = entity.withContentRetyped() as Entity<Cache.ContentType>? else
            {
            SiestaLog.log(.cache, ["WARNING: Unable to cache entity:", Cache.self, "expects", Cache.ContentType.self, "but content at this stage of the pipeline is", type(of: entity.content)])
            return
            }

        cache.workQueue.async
            {
            self.catchAndLogErrors(attemptingTo: "write cached entity")
                { try self.cache.writeEntity(cacheableEntity, forKey: self.key) }
            }
        }

    func updateTimestamp(_ timestamp: TimeInterval)
        {
        cache.workQueue.async
            {
            self.catchAndLogErrors(attemptingTo: "update entity timestamp")
                { try self.cache.updateEntityTimestamp(timestamp, forKey: self.key) }
            }
        }

    func remove()
        {
        cache.workQueue.async
            {
            self.catchAndLogErrors(attemptingTo: "remove entity from cache")
                { try self.cache.removeEntity(forKey: self.key) }
            }
        }

    private func catchAndLogErrors<T>(attemptingTo actionName: String, action: () throws -> T?) -> T?
        {
        do
            { return try action() }
        catch
            {
            SiestaLog.log(.cache, ["WARNING:", cache, "unable to", actionName, "for", key, ":", error])
            return nil
            }
        }

    var description: String
        { "\(key) in \(cache)" }
    }
