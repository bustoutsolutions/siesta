//
//  ResourceSpecBase.swift
//  Siesta
//
//  Created by Paul on 2015/6/20.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

@testable import Siesta
import Quick
import Nimble
import Nocilla
import Alamofire

class ResourceSpecBase: SiestaSpec
    {
    func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        { }

    override final func spec()
        {
        super.spec()

        func envFlag(key: String) -> Bool
            {
            let value = NSProcessInfo.processInfo().environment["Siesta_\(key)"] ?? ""
            return value == "1" || value == "true"
            }

        if envFlag("DelayAfterEachSpec")
            {
            // Nocilla’s threading is broken, and Travis exposes a race condition in it.
            // This delay is a workaround.
            print("Using awful sleep workaround for Nocilla’s thread safety problems \u{1f4a9}")
            afterEach { NSThread.sleepForTimeInterval(0.02) }  // must happen before clearStubs()
            }

        beforeSuite { LSNocilla.sharedInstance().start() }
        afterSuite  { LSNocilla.sharedInstance().stop() }
        afterEach   { LSNocilla.sharedInstance().clearStubs() }

        afterEach { fakeNow = nil }

        if envFlag("TestMultipleNetworkProviders")
            {
            runSpecsWithNetworkingProvider("default NSURLSession",   networking: NSURLSessionConfiguration.defaultSessionConfiguration())
            runSpecsWithNetworkingProvider("ephemeral NSURLSession", networking: NSURLSessionConfiguration.ephemeralSessionConfiguration())
            runSpecsWithNetworkingProvider("threaded NSURLSession",  networking:
                {
                let backgroundQueue = NSOperationQueue()
                return NSURLSession(
                    configuration: NSURLSessionConfiguration.defaultSessionConfiguration(),
                    delegate: nil,
                    delegateQueue: backgroundQueue)
                }())
            runSpecsWithNetworkingProvider("Alamofire networking", networking: Alamofire.Manager())
            }
        else
            { runSpecsWithDefaultProvider() }
        }

    private func runSpecsWithNetworkingProvider(description: String?, networking: NetworkingProviderConvertible)
        {
        context(debugStr(["with", description]))
            {
            self.runSpecsWithService
                { Service(baseURL: self.baseURL, networking: networking) }
            }
        }

    private func runSpecsWithDefaultProvider()
        {
        runSpecsWithService
            { Service(baseURL: self.baseURL) }
        }

    private func runSpecsWithService(serviceBuilder: Void -> Service)
        {
        let service  = specVar(serviceBuilder),
            resource = specVar { service().resource("/a/b") }

        resourceSpec(service, resource)
        }

    var baseURL: String
        {
        // Embedding the spec name in the API’s URL makes it easier to track down unstubbed requests, which sometimes
        // don’t arrive until a following spec has already started.

        return "https://" + QuickSpec.current().description
            .replacingRegex("_[A-Za-z]+Specswift_\\d+\\]$", "")
            .replacingRegex("[^A-Za-z0-9_]+", ".")
            .replacingRegex("^\\.+|\\.+$", "")
        }
    }


// MARK: - Request stubbing

func stubRequest(resource: () -> Resource, _ method: String) -> LSStubRequestDSL
    {
    return stubRequest(method, resource().url.absoluteString)
    }

func awaitNewData(req: Siesta.Request, alreadyCompleted: Bool = false)
    {
    expect(req.isCompleted) == alreadyCompleted
    let responseExpectation = QuickSpec.current().expectationWithDescription("awaiting response callback: \(req)")
    let successExpectation = QuickSpec.current().expectationWithDescription("awaiting success callback: \(req)")
    let newDataExpectation = QuickSpec.current().expectationWithDescription("awaiting newData callback: \(req)")
    req.onCompletion  { _ in responseExpectation.fulfill() }
       .onSuccess     { _ in successExpectation.fulfill() }
       .onFailure     { _ in fail("error callback should not be called") }
       .onNewData     { _ in newDataExpectation.fulfill() }
       .onNotModified { _ in fail("notModified callback should not be called") }
    QuickSpec.current().waitForExpectationsWithTimeout(1, handler: nil)
    expect(req.isCompleted) == true
    }

func awaitNotModified(req: Siesta.Request)
    {
    expect(req.isCompleted) == false
    let responseExpectation = QuickSpec.current().expectationWithDescription("awaiting response callback: \(req)")
    let successExpectation = QuickSpec.current().expectationWithDescription("awaiting success callback: \(req)")
    let notModifiedExpectation = QuickSpec.current().expectationWithDescription("awaiting notModified callback: \(req)")
    req.onCompletion  { _ in responseExpectation.fulfill() }
       .onSuccess     { _ in successExpectation.fulfill() }
       .onFailure     { _ in fail("error callback should not be called") }
       .onNewData     { _ in fail("newData callback should not be called") }
       .onNotModified { _ in notModifiedExpectation.fulfill() }
    QuickSpec.current().waitForExpectationsWithTimeout(1, handler: nil)
    expect(req.isCompleted) == true
    }

func awaitFailure(req: Siesta.Request, alreadyCompleted: Bool = false)
    {
    expect(req.isCompleted) == alreadyCompleted
    let responseExpectation = QuickSpec.current().expectationWithDescription("awaiting response callback: \(req)")
    let errorExpectation = QuickSpec.current().expectationWithDescription("awaiting failure callback: \(req)")
    req.onCompletion  { _ in responseExpectation.fulfill() }
       .onFailure     { _ in errorExpectation.fulfill() }
       .onSuccess     { _ in fail("success callback should not be called") }
       .onNewData     { _ in fail("newData callback should not be called") }
       .onNotModified { _ in fail("notModified callback should not be called") }

    QuickSpec.current().waitForExpectationsWithTimeout(1, handler: nil)
    expect(req.isCompleted) == true

    // When cancelling a request, Siesta immediately kills its end of the request, then sends a cancellation to the
    // network layer without waiting for a response. This causes spurious spec failures if LSNocilla’s clearStubs() gets
    // called before the network has a chance to finish, so we have to wait for the underlying request as well as Siesta.

    if alreadyCompleted
        { awaitUnderlyingNetworkRequest(req) }
    }

func awaitUnderlyingNetworkRequest(req: Siesta.Request)
    {
    if let netReq = req as? NetworkRequest
        {
        let networkExpectation = QuickSpec.current().expectationWithDescription("awaiting underlying network response: \(req)")
        pollUnderlyingCompletion(netReq, expectation: networkExpectation)
        QuickSpec.current().waitForExpectationsWithTimeout(1.0, handler: nil)
        }
    }

private func pollUnderlyingCompletion(req: NetworkRequest, expectation: XCTestExpectation)
    {
    if req.underlyingNetworkRequestCompleted
        { expectation.fulfill() }
    else
        {
        dispatch_on_main_queue(after: 0.0001)
            { pollUnderlyingCompletion(req, expectation: expectation) }
        }
    }


// MARK: - Clock stubbing

func setResourceTime(time: NSTimeInterval)
    {
    fakeNow = time
    }

// MARK: - Access to module internals

extension Resource
    {
    var internalCacheKey: EntityCacheKey
        { return cacheKey }
    }

extension Service
    {
    func testClone() -> Service
        {
        return Service(
            baseURL: baseURL?.absoluteString,
            networking: networkingProvider)
        }
    }
