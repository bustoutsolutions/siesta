//
//  PipelineSpec.swift
//  Siesta
//
//  Created by Paul on 2016/6/4.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble
import Nocilla

class PipelineSpec: ResourceSpecBase
    {
    override func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        {
        func appender(word: String) -> ResponseContentTransformer<Any,String>
            {
            return ResponseContentTransformer(skipWhenEntityMatchesOutputType: false)
                {
                let stringContent = $0.content as? String ?? ""
                guard !stringContent.containsString("error on \(word)") else
                    { return nil }
                return stringContent + word
                }
            }

        func makeRequest(expectSuccess expectSuccess: Bool = true)
            {
            stubRequest(resource, "GET").andReturn(200).withBody("🍕")
            let awaitRequest = expectSuccess ? awaitNewData : awaitFailure
            awaitRequest(resource().load(), alreadyCompleted: false)
            }

        beforeEach
            {
            service().configure
                {
                $0.config.pipeline.clear()
                for stage in [.decoding, .parsing, .model, .cleanup] as [PipelineStageKey]
                    {
                    $0.config.pipeline[stage].add(
                        appender(stage.description.prefix(3)))
                    }
                }
            }

        describe("stage order")
            {
            it("determines transformer order")
                {
                makeRequest()
                expect(resource().text) == "decparmodcle"
                }

            it("can reorder transformers already added")
                {
                service().configure
                    { $0.config.pipeline.order = [.rawData, .parsing, .cleanup, .model, .decoding] }
                makeRequest()
                expect(resource().text) == "parclemoddec"
                }

            it("will skip unlisted stages")
                {
                service().configure
                    { $0.config.pipeline.order = [.parsing, .decoding] }
                makeRequest()
                expect(resource().text) == "pardec"
                }

            it("supports custom keys")
                {
                service().configure
                    {
                    $0.config.pipeline.order.insert(.funk, atIndex: 3)
                    $0.config.pipeline.order.insert(.silence, atIndex: 1)
                    $0.config.pipeline[.funk].add(appender("♫"))
                    }
                makeRequest()
                expect(resource().text) == "decpar♫modcle"
                }
            }

        describe("individual stage")
            {
            it("runs transformers in the order added")
                {
                service().configure
                    {
                    for solfegg in ["do", "re", "mi"]
                        { $0.config.pipeline[.decoding].add(appender(solfegg)) }
                    }
                makeRequest()
                expect(resource().text) == "decdoremiparmodcle"
                }

            it("can clear and replace transformers")
                {
                service().configure
                    {
                    $0.config.pipeline[.model].removeTransformers()
                    $0.config.pipeline[.model].add(appender("ti"))
                    }
                makeRequest()
                expect(resource().text) == "decparticle"
                }
            }

        describe("cache")
            {
            func configureCache(cache: EntityCache, at stageKey: PipelineStageKey)
                {
                service().configure
                    { $0.config.pipeline[stageKey].cache = cache }
                }

            func fakeCacheHit(content: String) -> String
                { return resource().url.absoluteString + ":" + content }

            func waitForCacheRead(cache: TestCache)
                { expect(cache.receivedCacheRead).toEventually(beTrue()) }

            func waitForCacheWrite(cache: TestCache)
                { expect(cache.receivedCacheWrite).toEventually(beTrue()) }

            describe("read")
                {
                let cache0 = specVar { TestCache(returning: "cache0") },
                    cache1 = specVar { TestCache(returning: "cache1") }

                it("reinflates resource with cached content")
                    {
                    configureCache(cache0(), at: .cleanup)
                    expect(resource().text).toEventually(equal(
                        fakeCacheHit("cache0")))
                    }

                it("inflates empty resource if no cached data")
                    {
                    let emptyCache = TestCache()
                    configureCache(emptyCache, at: .cleanup)
                    resource()
                    waitForCacheRead(emptyCache)
                    expect(resource().text) == ""
                    }

                it("ignores cached data if resource populated before cache read completes")
                    {
                    configureCache(cache0(), at: .cleanup)
                    resource().overrideLocalContent("no race conditions here...except in the specs")
                    waitForCacheRead(cache0())
                    expect(resource().text) == "no race conditions here...except in the specs"
                    }

                it("prevents loadIfNeeded() network access if cached data is fresh")
                    {
                    configureCache(cache0(), at: .cleanup)
                    expect(resource().latestData).toEventuallyNot(beNil())
                    expect(resource().loadIfNeeded()).to(beNil())
                    }

                it("allows loadIfNeeded() network access if cached data is stale")
                    {
                    let aWhileAgo = NSDate.timeIntervalSinceReferenceDate() - 1000
                    configureCache(TestCache(returning: "foo", timestamp: aWhileAgo), at: .cleanup)
                    expect(resource().latestData).toEventuallyNot(beNil())
                    stubRequest(resource, "GET").andReturn(200)
                    awaitNewData(resource().loadIfNeeded()!)
                    }

                it("prefers cache hits from later stages")
                    {
                    configureCache(cache1(), at: .cleanup)
                    configureCache(cache0(), at: .model)
                    expect(resource().text).toEventually(equal(
                        fakeCacheHit("cache1")))
                    }

                it("processes cached content with the following stages’ transformers")
                    {
                    configureCache(cache0(), at: .rawData)
                    expect(resource().text).toEventually(equal(
                        fakeCacheHit("cache0decparmodcle")))
                    }

                it("skips cached content that fails subsequent transformation")
                    {
                    configureCache(cache0(), at: .decoding)
                    configureCache(TestCache(returning: "error on cleanup"), at: .parsing)  // see appender() above
                    expect(resource().text).toEventually(equal(
                        fakeCacheHit("cache0parmodcle")))
                    }
                }

            describe("write")
                {
                func expectCacheWrite(to cache: TestCache, content: String)
                    {
                    waitForCacheWrite(cache)
                    expect(Array(cache.entries.keys)) == [resource().url.absoluteString]
                    expect(cache.entries.values.first?.typedContent()) == content
                    }

                it("caches new data on success")
                    {
                    let testCache = TestCache()
                    configureCache(testCache, at: .cleanup)
                    makeRequest()
                    expectCacheWrite(to: testCache, content: "decparmodcle")
                    }

                it("writes each stage’s output to that stage’s cache")
                    {
                    let parCache = TestCache(),
                        modCache = TestCache()
                    configureCache(parCache, at: .parsing)
                    configureCache(modCache, at: .model)
                    makeRequest()
                    expectCacheWrite(to: parCache, content: "decpar")
                    expectCacheWrite(to: modCache, content: "decparmod")
                    }

                it("does not cache errors")
                    {
                    configureCache(UnwritableCache(), at: .parsing) // Neither at the failed stage...
                    configureCache(UnwritableCache(), at: .model)   // ...nor at a subsequent ones

                    service().configureTransformer("**", atStage: .parsing)
                        { (_: String, _) -> NSDate? in nil }

                    makeRequest(expectSuccess: false)
                    }

                pending("updates cached data timestamp on 304") { }

                pending("clears cached data on local override") { }
                }
            }

        it("can clear previously configured transformers")
            {
            service().configure
                { $0.config.pipeline.clear() }
            makeRequest()
            expect(resource().latestData?.content is NSData) == true
            }
        }
    }


private extension PipelineStageKey
    {
    static let
        funk    = PipelineStageKey(description: "funk"),
        silence = PipelineStageKey(description: "silence")
    }

private class TestCache: EntityCache
    {
    var fakeHit: String?
    var fakeTimestamp: NSTimeInterval?
    var receivedCacheRead = false, receivedCacheWrite = false
    var entries: [String:Entity] = [:]

    init(returning content: String? = nil, timestamp: NSTimeInterval? = nil)
        {
        self.fakeHit = content
        self.fakeTimestamp = timestamp
        }

    func readEntity(forKey key: String) -> Entity?
        {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(0.2 * Double(NSEC_PER_SEC))),
            dispatch_get_main_queue())
            { self.receivedCacheRead = true }

        guard let fakeHit = fakeHit else
            { return nil }

        return Entity(content: key + ":" + fakeHit, headers: [:], timestamp: fakeTimestamp)
        }

    func writeEntity(entity: Entity, forKey key: String)
        {
        dispatch_async(dispatch_get_main_queue())
            {
            self.entries[key] = entity
            self.receivedCacheWrite = true
            }
        }
    }

private struct UnwritableCache: EntityCache
    {
    func readEntity(forKey key: String) -> Entity?
        { return nil }

    func writeEntity(entity: Entity, forKey key: String)
        {
        fatalError("cache should never be written to")
        }
    }

private extension String
    {
    func prefix(n: Int) -> String
        {
        return self[startIndex ..< startIndex.advancedBy(n)]
        }
    }
