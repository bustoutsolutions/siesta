//
//  PerformanceTests.swift
//  Siesta
//
//  Created by Paul on 2016/9/27.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation
import XCTest
import Siesta

class SiestaPerformanceTests: XCTestCase
    {
    var service: Service!
    var networkStub: NetworkStub!

    override func setUp()
        {
        networkStub = NetworkStub()
        service = Service(baseURL: "http://test.ing", networking: networkStub)
        }

    override func tearDown()
        {
        NotificationCenter.default
            .post(
                name: NSNotification.Name("Siesta.MemoryWarningNotification"),
                object: nil)
        }

    func testGetExistingResourcesByURL()
        {
        measure { self.exerciseResourceCache(uniqueResources: 20, iters: 20000) }
        }

    func testGetExistingResourcesByPath()
        {
        let uniqueResources = 20
        let iters = 20000
        measure
            {
            self.setUp()  // Important to start empty each time
            let paths = (0 ..< uniqueResources).map { "/items/\($0)" }
            for n in 0 ..< iters
                { _ = self.service.resource(paths[n % uniqueResources]) }
            }
        }

    func testGetResourceForNilURL()
        {
        measure
            {
            for _ in 0 ..< 20000
                { _ = self.service.resource(absoluteURL: nil) }
            }
        }

    func testResourceCacheGrowth()
        {
        measure { self.exerciseResourceCache(uniqueResources: 10000, iters: 10000) }
        }

    func testResourceCacheChurn()
        {
        measure { self.exerciseResourceCache(uniqueResources: 10000, iters: 10000, countLimit: 100) }
        }

    func exerciseResourceCache(uniqueResources: Int, iters: Int, countLimit: Int = 100000)
        {
        setUp()  // Important to start empty each time
        service.cachedResourceCountLimit = countLimit
        let urls = (0 ..< uniqueResources).map { URL(string: "/items/\($0)") }
        for n in 0 ..< iters
            { _ = service.resource(absoluteURL: urls[n % uniqueResources]) }
        }

    func testObserverChurn5()
        {
        measure { self.churnItUp(observerCount: 5, reps: 2000) }
        }

    func testObserverChurn100()
        {
        measure { self.churnItUp(observerCount: 100, reps: 1000) }
        }

    private func churnItUp(observerCount: Int, reps: Int)
        {
        // Note no setUp() per measure() here. We expect stable performance here even
        // with an existing resource. Lack of that will show as high stdev in test results.

        let resource = service.resource("/observed")
        let observers = (1...observerCount).map { _ in TestObserver() }

        for n in 0 ..< reps
            {
            var x = 0
            resource.addObserver(observers[n % observerCount])
            resource.addObserver(owner: observers[(n * 7) % observerCount])
                { _ in x += 1 }
            resource.removeObservers(ownedBy: observers[(n * 3) % observerCount])
            }
        }

    func testObserverOwnerChurn5()
        {
        measure { self.churnOwnersUp(observerCount: 5, reps: 2000) }
        }

    func testObserverOwnerChurn100()
        {
        measure { self.churnOwnersUp(observerCount: 100, reps: 1000) }
        }

    private func churnOwnersUp(observerCount: Int, reps: Int)
        {
        let resource = service.resource("/observed")
        var observers = (1...observerCount).map { _ in TestObserver() }

        for n in 0 ..< reps
            {
            var x = 0
            resource.addObserver(observers[n % observerCount])
            resource.addObserver(owner: observers[(n * 7) % observerCount])
                { _ in x += 1 }
            observers[(n * 3) % observerCount] = TestObserver()
            }
        }

    func testRequestHooks()
        {
        measure
            {
            var callbacks = 0
            self.timeRequests(resourceCount: 1, reps: 200)
                {
                let req = $0.load()
                for _ in 0 ..< 499  // 500th fulfills expectation
                    { req.onCompletion { _ in callbacks += 1 } }
                return req
                }
            }
        }

    func testBareRequest()
        {
        measure
            { self.timeRequests(resourceCount: 300, reps: 10) { $0.request(.get) } }
        }

    func testLoadRequest()
        {
        measure
            { self.timeRequests(resourceCount: 300, reps: 10) { $0.load() } }
        }

    private func timeRequests(resourceCount: Int, reps: Int, makeRequest: (Resource) -> Request)
        {
        for n in stride(from: 0, to: resourceCount, by: 2)
            { networkStub.responses["/zlerp\(n)"] = ResponseStub(data: Data(count: 65536)) }

        let resources = (0 ..< resourceCount).map
            { service.resource("/zlerp\($0)") }

        let load = self.expectation(description: "load")
        var responsesPending = reps * resources.count
        for _ in 0 ..< reps
            {
            for resource in resources
                {
                makeRequest(resource).onCompletion
                    {
                    _ in
                    responsesPending -= 1
                    if responsesPending <= 0
                        { load.fulfill() }
                    }
                }
            }
        self.waitForExpectations(timeout: 1)
        }

    func testNotifyManyObservers()
        {
        networkStub.responses["/zlerp"] = ResponseStub(data: Data(count: 65536))

        let resource = service.resource("/zlerp")
        for _ in 0 ..< 5000
            { resource.addObserver(TestObserver(), owner: self) }

        measure
            {
            let load = self.expectation(description: "load")
            let reps = 10
            var responsesPending = reps
            for _ in 0 ..< reps
                {
                resource.load().onCompletion
                    {
                    _ in
                    responsesPending -= 1
                    if responsesPending <= 0
                        { load.fulfill() }
                    }
                }
            self.waitForExpectations(timeout: 1)
            }
        }

    func testLoadIfNeeded()
        {
        networkStub.responses["/bjempf"] = ResponseStub(data: Data())
        let resource = service.resource("/bjempf")
        let load = self.expectation(description: "load")
        resource.load().onCompletion { _ in load.fulfill() }
        self.waitForExpectations(timeout: 1)

        measure
            {
            for _ in 0 ..< 100000
                {
                resource.loadIfNeeded()
                resource.loadIfNeeded()
                resource.loadIfNeeded()
                }
            }
        }
    }

struct NetworkStub: NetworkingProvider
    {
    var responses: [String:ResponseStub] = [:]
    let dummyHeaders =
        [
        "A-LITTLE": "madness in the Spring",
        "Is-wholesome": "even for the King",
        "But-God-be": "with the Clown",
        "Who-ponders": "this tremendous scene",
        "This-whole": "experiment of green",
        "As-if-it": "were his own!",

        "X-Author": "Emily Dickinson"
        ]

    func startRequest(
            _ request: URLRequest,
            completion: @escaping RequestNetworkingCompletionCallback)
        -> RequestNetworking
        {
        let responseStub = responses[request.url!.path]
        let statusCode = (responseStub != nil) ? 200 : 404
        var headers = dummyHeaders
        headers["Content-Type"] = responseStub?.contentType
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers)

        completion(response, responseStub?.data, nil)
        return RequestStub()
        }
    }

struct ResponseStub
    {
    let contentType: String = "application/octet-stream"
    let data: Data
    }

struct RequestStub: RequestNetworking
    {
    func cancel() { }

    /// Returns raw data used for progress calculation.
    var transferMetrics: RequestTransferMetrics
        {
        return RequestTransferMetrics(
                requestBytesSent: 0,
                requestBytesTotal: nil,
                responseBytesReceived: 0,
                responseBytesTotal: nil)
        }
    }

class TestObserver: ResourceObserver
    {
    public var eventCount = 0

    func resourceChanged(_ resource: Resource, event: ResourceEvent)
        { eventCount += 1 }
    }
