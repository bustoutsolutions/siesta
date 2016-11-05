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
    func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource)
        { }

    override final func spec()
        {
        super.spec()

        func envFlag(_ key: String) -> Bool
            {
            let value = ProcessInfo.processInfo.environment["Siesta_\(key)"] ?? ""
            return value == "1" || value == "true"
            }

        if envFlag("DelayAfterEachSpec")
            {
            // Nocilla’s threading is broken, and Travis exposes a race condition in it.
            // This delay is a workaround.
            print("Using awful sleep workaround for Nocilla’s thread safety problems \u{1f4a9}")
            afterEach { Thread.sleep(forTimeInterval: 0.02) }  // must happen before clearStubs()
            }

        beforeSuite { LSNocilla.sharedInstance().start() }
        afterSuite  { LSNocilla.sharedInstance().stop() }
        afterEach   { LSNocilla.sharedInstance().clearStubs() }

        afterEach { fakeNow = nil }

        if envFlag("TestMultipleNetworkProviders")
            {
            runSpecsWithNetworkingProvider("default URLSession",   networking: URLSessionConfiguration.default)
            runSpecsWithNetworkingProvider("ephemeral URLSession", networking: URLSessionConfiguration.ephemeral)
            runSpecsWithNetworkingProvider("threaded URLSession",  networking:
                {
                let backgroundQueue = OperationQueue()
                return URLSession(
                    configuration: URLSessionConfiguration.default,
                    delegate: nil,
                    delegateQueue: backgroundQueue)
                }())
            runSpecsWithNetworkingProvider("Alamofire networking", networking: Alamofire.SessionManager.default)
            }
        else
            { runSpecsWithDefaultProvider() }
        }

    private func runSpecsWithNetworkingProvider(_ description: String?, networking: NetworkingProviderConvertible)
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

    private func runSpecsWithService(_ serviceBuilder: @escaping (Void) -> Service)
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
            .replacing(regex: "_[A-Za-z]+Specswift_\\d+\\]$", with: "")
            .replacing(regex: "[^A-Za-z0-9_]+", with: ".")
            .replacing(regex: "^\\.+|\\.+$", with: "")
        }
    }


// MARK: - Request stubbing

@discardableResult
func stubRequest(_ resource: () -> Resource, _ method: String) -> LSStubRequestDSL
    {
    return stubRequest(method, resource().url.absoluteString as NSString)
    }

func awaitNewData(_ req: Siesta.Request, alreadyCompleted: Bool = false)
    {
    expect(req.isCompleted) == alreadyCompleted
    let responseExpectation = QuickSpec.current().expectation(description: "awaiting response callback: \(req)")
    let successExpectation = QuickSpec.current().expectation(description: "awaiting success callback: \(req)")
    let newDataExpectation = QuickSpec.current().expectation(description: "awaiting newData callback: \(req)")
    req.onCompletion  { _ in responseExpectation.fulfill() }
       .onSuccess     { _ in successExpectation.fulfill() }
       .onFailure     { _ in fail("error callback should not be called") }
       .onNewData     { _ in newDataExpectation.fulfill() }
       .onNotModified { _ in fail("notModified callback should not be called") }
    QuickSpec.current().waitForExpectations(timeout: 1, handler: nil)
    expect(req.isCompleted) == true
    }

func awaitNotModified(_ req: Siesta.Request)
    {
    expect(req.isCompleted) == false
    let responseExpectation = QuickSpec.current().expectation(description: "awaiting response callback: \(req)")
    let successExpectation = QuickSpec.current().expectation(description: "awaiting success callback: \(req)")
    let notModifiedExpectation = QuickSpec.current().expectation(description: "awaiting notModified callback: \(req)")
    req.onCompletion  { _ in responseExpectation.fulfill() }
       .onSuccess     { _ in successExpectation.fulfill() }
       .onFailure     { _ in fail("error callback should not be called") }
       .onNewData     { _ in fail("newData callback should not be called") }
       .onNotModified { _ in notModifiedExpectation.fulfill() }
    QuickSpec.current().waitForExpectations(timeout: 1, handler: nil)
    expect(req.isCompleted) == true
    }

func awaitFailure(_ req: Siesta.Request, alreadyCompleted: Bool = false)
    {
    expect(req.isCompleted) == alreadyCompleted
    let responseExpectation = QuickSpec.current().expectation(description: "awaiting response callback: \(req)")
    let errorExpectation = QuickSpec.current().expectation(description: "awaiting failure callback: \(req)")
    req.onCompletion  { _ in responseExpectation.fulfill() }
       .onFailure     { _ in errorExpectation.fulfill() }
       .onSuccess     { _ in fail("success callback should not be called") }
       .onNewData     { _ in fail("newData callback should not be called") }
       .onNotModified { _ in fail("notModified callback should not be called") }

    QuickSpec.current().waitForExpectations(timeout: 1, handler: nil)
    expect(req.isCompleted) == true

    // When cancelling a request, Siesta immediately kills its end of the request, then sends a cancellation to the
    // network layer without waiting for a response. This causes spurious spec failures if LSNocilla’s clearStubs() gets
    // called before the network has a chance to finish, so we have to wait for the underlying request as well as Siesta.

    if alreadyCompleted
        { awaitUnderlyingNetworkRequest(req) }
    }

func awaitUnderlyingNetworkRequest(_ req: Siesta.Request)
    {
    if let netReq = req as? NetworkRequest
        {
        let networkExpectation = QuickSpec.current().expectation(description: "awaiting underlying network response: \(req)")
        pollUnderlyingCompletion(netReq, expectation: networkExpectation)
        QuickSpec.current().waitForExpectations(timeout: 1.0, handler: nil)
        }
    }

private func pollUnderlyingCompletion(_ req: NetworkRequest, expectation: XCTestExpectation)
    {
    if req.underlyingNetworkRequestCompleted
        { expectation.fulfill() }
    else
        {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.0001)
            { pollUnderlyingCompletion(req, expectation: expectation) }
        }
    }


// MARK: - Siesta internals

func setResourceTime(_ time: TimeInterval)
    {
    fakeNow = time
    }

// Checks for removed observers normally get batched up and run later after a delay.
// This call waits for that to finish so we can check who’s left observing and who isn’t.
//
// Since there’s no way to directly detect the cleanup, and thus no positive indicator to
// wait for, we just wait for all tasks currently queued on the main thread to complete.

func awaitObserverCleanup(for resource: Resource?)
    {
    let cleanupExpectation = QuickSpec.current().expectation(description: "awaitObserverCleanup")
    DispatchQueue.main.async
        { cleanupExpectation.fulfill() }
    QuickSpec.current().waitForExpectations(timeout: 1, handler: nil)
    }

