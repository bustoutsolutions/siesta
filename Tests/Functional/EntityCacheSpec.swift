//
//  EntityCacheSpec.swift
//  Siesta
//
//  Created by Paul on 2018/3/10.
//  Copyright © 2018 Bust Out Solutions. All rights reserved.
//

@testable import Siesta

import Foundation
import Quick
import Nimble

class EntityCacheSpec: ResourceSpecBase
    {
    override func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource)
        {
        func configureCache<C: EntityCache>(
                _ cache: C,
                for pattern: ConfigurationPatternConvertible = "**",
                at stageKey: PipelineStageKey)
            {
            service().configure(pattern)
                { $0.pipeline[stageKey].cacheUsing(cache) }
            }

        func waitForCacheRead(_ cache: TestCache)
            {
            expect(cache.receivedCacheRead).toEventually(beTrue())
            cache.receivedCacheRead = false
            }

        func waitForCacheWrite(_ cache: TestCache)
            {
            expect(cache.receivedCacheWrite).toEventually(beTrue())
            cache.receivedCacheWrite = false
            }

        beforeEach
            {
            configureStageNameAppenders(in: service())
            }

        describe("read")
            {
            let cache0 = specVar { TestCache(returningForTestResource: "cache0") },
                cache1 = specVar { TestCache(returningForTestResource: "cache1") }

            it("returns an empty resource, then populates cached content")
                {
                configureCache(cache0(), at: .cleanup)
                expect(resource().latestData).to(beNil())
                expect(resource().text).toEventually(equal("cache0"))
                }

            it("leaves resource empty if no cached data")
                {
                let emptyCache = TestCache("empty")
                configureCache(emptyCache, at: .cleanup)
                _ = resource().latestData
                waitForCacheRead(emptyCache)
                expect(resource().latestData).to(beNil())
                }

            it("ignores cached data if latestData populated before cache read completes")
                {
                configureCache(cache0(), at: .cleanup)
                expect(resource().latestData).to(beNil())  // trigger cache read
                resource().overrideLocalContent(with: "no race conditions here")
                waitForCacheRead(cache0())
                expect(resource().text) == "no race conditions here"
                }

            describe("loadIfNeeded() called once")
                { addLoadIfNeededCacheSpecs(callCount: 1) }

            describe("loadIfNeeded() called multiple times")
                { addLoadIfNeededCacheSpecs(callCount: 3) }

            func addLoadIfNeededCacheSpecs(callCount: Int)
                {
                let eventRecorder = specVar { ObserverEventRecorder() }

                func loadIfNeededAndRecordEvents(expectingContent content: String)
                    {
                    NetworkStub.add(
                        .get, resource,
                        returning: HTTPResponse(body: "net"))
                    resource().addObserver(eventRecorder())
                    let requests = (1...callCount).map
                        {
                        _ in resource().loadIfNeeded()?
                            .onSuccess { expect($0.text) == content }
                        }
                    for request in requests
                        { expect(request).notTo(beNil()) }
                    if let firstRequest = requests.first!
                        { awaitNewData(firstRequest) }
                    expect(resource().isLoading).toEventually(beFalse())
                    resource().removeObservers(ownedBy: eventRecorder())
                    awaitObserverCleanup(for: resource())
                    }

                it("waits for cache hit before proceeding to network")
                    {
                    configureCache(cache0(), at: .cleanup)
                    loadIfNeededAndRecordEvents(expectingContent: "cache0")
                    expect(eventRecorder().events) ==
                        [
                        "newData(cache) latestData=cache0 isLoading=true",
                        "notModified latestData=cache0 isLoading=false"
                        ]
                    }

                it("after populated from cache, does not use network if data is fresh")
                    {
                    configureCache(cache0(), at: .cleanup)
                    expect(resource().latestData).toEventuallyNot(beNil())
                    expect(resource().loadIfNeeded()).to(beNil())
                    }

                it("proceeds to network on cache miss")
                    {
                    configureCache(TestCache("empty"), at: .cleanup)
                    loadIfNeededAndRecordEvents(expectingContent: "decparmodcle")
                    expect(eventRecorder().events) ==
                        [
                        "requested latestData= isLoading=true",
                        "newData(network) latestData=decparmodcle isLoading=false"
                        ]
                    }

                it("proceeds to network if cached data is stale")
                    {
                    setResourceTime(1000)
                    configureCache(cache0(), at: .cleanup)

                    setResourceTime(2000)

                    // Request only yields final result from network
                    loadIfNeededAndRecordEvents(expectingContent: "decparmodcle")

                    // Observers see cache hit, then network result
                    expect(eventRecorder().events) ==
                        [
                        "newData(cache) latestData=cache0 isLoading=true",
                        "requested latestData=cache0 isLoading=true",
                        "newData(network) latestData=decparmodcle isLoading=false"
                        ]
                    }
                }

            it("prefers cache hits from later stages")
                {
                configureCache(cache1(), at: .cleanup)
                configureCache(cache0(), at: .model)
                expect(resource().text).toEventually(equal("cache1"))
                }

            it("processes cached content with the subsequent stages’ transformers")
                {
                configureCache(cache0(), at: .rawData)
                expect(resource().text).toEventually(equal("cache0decparmodcle"))
                }

            it("skips cached content that fails subsequent transformation")
                {
                configureCache(cache0(), at: .decoding)
                configureCache(
                    TestCache(returningForTestResource:
                        "error on cleanup"),  // "error on" triggers error; see stringAppendingTransformer()
                    at: .parsing)
                expect(resource().text).toEventually(equal("cache0parmodcle"))
                }
            }

        describe("write")
            {
            @discardableResult
            func stubAndAwaitRequestWithoutLoading(for resource: Resource, method: RequestMethod) -> Request
                {
                NetworkStub.add(method, { resource })
                let req = resource.request(method)
                awaitNewData(req, initialState: .inProgress)
                return req
                }

            func expectCacheWrite(to cache: TestCache, content: String)
                {
                waitForCacheWrite(cache)
                expect(Array(cache.entries.keys)) == [TestCacheKey(forTestResourceIn: cache)]
                expect(cache.entries.values.first?.typedContent()) == content
                }

            it("caches new data on a successful load()")
                {
                let testCache = TestCache("new data")
                configureCache(testCache, at: .cleanup)
                stubAndAwaitRequest(for: resource())
                expectCacheWrite(to: testCache, content: "decparmodcle")
                }

            it("writes each stage’s output to that stage’s cache")
                {
                let parCache = TestCache("par cache"),
                    modCache = TestCache("mod cache")
                configureCache(parCache, at: .parsing)
                configureCache(modCache, at: .model)
                stubAndAwaitRequest(for: resource())
                expectCacheWrite(to: parCache, content: "decpar")
                expectCacheWrite(to: modCache, content: "decparmod")
                }

            it("does not cache errors")
                {
                configureCache(UnwritableCache(), at: .parsing) // Neither at the failed stage...
                configureCache(UnwritableCache(), at: .model)   // ...nor subsequent ones

                service().configureTransformer("**", atStage: .parsing)
                    { (_: Entity<String>) -> Date? in nil }

                stubAndAwaitRequest(for: resource(), expectSuccess: false)
                }

            it("updates cached data timestamp on 304")
                {
                let testCache = TestCache("updated data")
                configureCache(testCache, at: .cleanup)
                setResourceTime(1000)
                stubAndAwaitRequest(for: resource())

                setResourceTime(2000)
                NetworkStub.add(.get, resource, status: 304)
                awaitNotModified(resource().load())
                expect(testCache.entries[TestCacheKey(forTestResourceIn: testCache)]?.timestamp)
                    .toEventually(equal(2000))
                }

            it("preserves the timestamp of cached data")
                {
                let testCache = UnwritableCache(cachedValue:
                    Entity(content: "hi", charset: nil, headers: [:], timestamp: 2001))
                configureCache(testCache, at: .cleanup)

                setResourceTime(2010)
                awaitNewData(resource().loadIfNeeded()!)
                expect(resource().latestData?.timestamp) == 2001
                }

            it("clears cached data on local override")
                {
                let testCache = TestCache("local override")
                configureCache(testCache, at: .cleanup)
                testCache.entries[TestCacheKey(forTestResourceIn: testCache)] =
                    Entity<Any>(content: "should go away", contentType: "text/string")

                resource().overrideLocalData(
                    with: Entity<Any>(content: "should not be cached", contentType: "text/string"))

                expect(testCache.entries).toEventually(beEmpty())
                }

            it("does not write previously cached data back to the cache when reading it")
                {
                let testCache = TestCache("does not write previously cached")
                configureCache(testCache, at: .parsing)
                configureCache(UnwritableCache(), at: .model)
                configureCache(UnwritableCache(), at: .cleanup)

                testCache.entries[TestCacheKey(forTestResourceIn: testCache)] =
                    Entity(content: "🌮", contentType: "text/plain")
                awaitNewData(resource().loadIfNeeded()!, initialState: .inProgress)
                expect(resource().typedContent()) == "🌮modcle"
                }

            it("does not cache anything for call to Resource.request() without load()")
                {
                configureCache(UnwritableCache(), at: .cleanup)
                stubAndAwaitRequestWithoutLoading(for: resource(), method: .get)
                }

            it("caches new data for a GET on the same resource passed to load(using:)")
                {
                let testCache = TestCache("new data from load(using:)")
                configureCache(testCache, at: .cleanup)
                let req = stubAndAwaitRequestWithoutLoading(for: resource(), method: .get)
                resource().load(using: req)
                expectCacheWrite(to: testCache, content: "decparmodcle")
                }

            it("does not cache anything for a non-GET request, even if passed to load(using:)")
                {
                configureCache(UnwritableCache(), at: .cleanup)
                for method in RequestMethod.allCases
                    where method != .get
                        {
                        let req = stubAndAwaitRequestWithoutLoading(for: resource(), method: method)
                        resource().load(using: req)
                        }
                }

            it("does not cache anything for a GET request for a different resource, even if passed to load(using:)")
                {
                let otherResource = service().resource("/otherResource")
                configureCache(UnwritableCache(), at: .cleanup)
                let req = stubAndAwaitRequestWithoutLoading(for: otherResource, method: .get)
                resource().load(using: req)
                }

            func stubText(_ text: String)
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(
                        headers: ["content-type": "text/plain; charset=utf-8"],
                        body: text))
                }

            it("will restore cache state to an older request if passed to load(using:)")
                {
                let testCache = TestCache("restore cache state")
                configureCache(testCache, at: .model)
                service().configure
                    {
                    $0.pipeline[.decoding].removeTransformers()
                    $0.pipeline[.decoding].add(TextResponseTransformer())
                    }

                stubText("🌮")
                let originalReq = resource().load()
                awaitNewData(originalReq, initialState: .inProgress)
                expectCacheWrite(to: testCache, content: "🌮parmod")

                stubText("🧇")
                awaitNewData(resource().load(), initialState: .inProgress)
                expectCacheWrite(to: testCache, content: "🧇parmod")

                resource().load(using: originalReq)
                expectCacheWrite(to: testCache, content: "🌮parmod")
                }

            it("will restore cache state to original state if original cache request is passed to load(using:)")
                {
                let testCacheMod = TestCache("restore cache state - mod")
                let testCacheCle = TestCache("restore cache state - cle")
                configureCache(testCacheMod, at: .model)
                configureCache(testCacheMod, at: .model)
                configureCache(testCacheCle, at: .cleanup)
                service().configure
                    {
                    $0.pipeline[.decoding].removeTransformers()
                    $0.pipeline[.decoding].add(TextResponseTransformer())
                    }

                testCacheMod.entries[TestCacheKey(forTestResourceIn: testCacheMod)] =
                    Entity(content: "🌮", contentType: "text/plain")
                let originalReq = resource().loadIfNeeded()!
                awaitNewData(originalReq, initialState: .inProgress)
                expect(resource().typedContent()) == "🌮cle"

                stubText("🧇")
                awaitNewData(resource().load(), initialState: .inProgress)
                expectCacheWrite(to: testCacheMod, content: "🧇parmod")
                expectCacheWrite(to: testCacheCle, content: "🧇parmodcle")

                resource().load(using: originalReq)
                expectCacheWrite(to: testCacheMod, content: "🌮")
                expectCacheWrite(to: testCacheCle, content: "🌮cle")
                }
            }

        func exerciseCache()
            {
            stubAndAwaitRequest(for: resource())
            resource().overrideLocalData(
                with: Entity<Any>(content: "should not be cached", contentType: "text/string"))
            }

        it("can specify a custom workQueue")
            {
            // MainThreadCache will blow up if any cache methods touched off main thread
            let cache = MainThreadCache()
            configureCache(cache, at: .model)

            expect(resource().text).toEventually(equal("bicycle"))
            exerciseCache()

            expect(cache.calls).toEventually(equal(["readEntity", "writeEntity", "removeEntity"]))
            }

        it("can opt out by returning a nil key")
            {
            configureCache(KeylessCache(), at: .model)
            exerciseCache()
            }
        }
    }


private class TestCache: EntityCache
    {
    var name: String
    var receivedCacheRead = false, receivedCacheWrite = false
    var entries: [TestCacheKey:Entity<Any>] = [:]

    init(_ name: String)
        { self.name = name }

    init(returningForTestResource content: String)
        {
        name = "cache that returns \(content)"
        entries[TestCacheKey(forTestResourceIn: self)] =
            Entity<Any>(content: content, contentType: "text/string")
        }

    func key(for resource: Resource) -> TestCacheKey?
        { TestCacheKey(cache: self, path: resource.url.path) }

    func readEntity(forKey key: TestCacheKey) -> Entity<Any>?
        {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05)
            { self.receivedCacheRead = true }

        return DispatchQueue.main.sync
            { entries[key] }
        }

    func writeEntity(_ entity: Entity<Any>, forKey key: TestCacheKey)
        {
        DispatchQueue.main.async
            {
            self.entries[key] = entity
            self.receivedCacheWrite = true
            }
        }

    func removeEntity(forKey key: TestCacheKey)
        {
        _ = DispatchQueue.main.sync
            { entries.removeValue(forKey: key) }
        }
    }

private struct TestCacheKey: Hashable
    {
    let string: String

    // Including a cache-specific prefix in the key ensure that pipeline correctly
    // associates a cache with its own keys (as opposed to some other cache’s).

    init(forTestResourceIn cache: TestCache)
        { self.init(cache: cache, path: "/a/b") }  // standard resource() passed to specs has path /a/b

    init(cache: TestCache, path: String)
        { string = "\(cache.name)•\(path)" }
    }

private class MainThreadCache: EntityCache
    {
    var calls: [String] = []

    func key(for resource: Resource) -> String?
        { "bi" }

    func readEntity(forKey key: String) -> Entity<Any>?
        {
        recordCall("readEntity")
        return Entity<Any>(content: "\(key)cy", contentType: "text/bogus")
        }

    func writeEntity(_ entity: Entity<Any>, forKey key: String)
        { recordCall("writeEntity") }

    func removeEntity(forKey key: String)
        { recordCall("removeEntity") }

    var workQueue: DispatchQueue
        { DispatchQueue.main }

    private func recordCall(_ name: String)
        {
        if !Thread.isMainThread
            { fatalError("MainThreadCache method not called on main queue") }
        calls.append(name)
        }
    }

private class KeylessCache: EntityCache
    {
    func key(for resource: Resource) -> String?
        { nil }

    func readEntity(forKey key: String) -> Entity<Any>?
        { fatalError("should not be called") }

    func writeEntity(_ entity: Entity<Any>, forKey key: String)
        { fatalError("should not be called") }

    func removeEntity(forKey key: String)
        { fatalError("should not be called") }

    var workQueue: DispatchQueue
        { fatalError("should not be called") }
    }

private struct UnwritableCache: EntityCache
    {
    let cachedValue: Entity<Any>?

    init(cachedValue: Entity<Any>? = nil)
        { self.cachedValue = cachedValue }

    func key(for resource: Resource) -> URL?
        { resource.url }

    func readEntity(forKey key: URL) -> Entity<Any>?
        { cachedValue }

    func writeEntity(_ entity: Entity<Any>, forKey key: URL)
        { fail("cache should never be written to") }

    func removeEntity(forKey key: URL)
        { fail("cache should never be written to") }
    }

private class ObserverEventRecorder: ResourceObserver
    {
    var events = [String]()

    func resourceChanged(_ resource: Resource, event: ResourceEvent)
        {
        if case .observerAdded = event
            { return }
        events.append("\(event) latestData=\(resource.text) isLoading=\(resource.isLoading)")
        }
    }
