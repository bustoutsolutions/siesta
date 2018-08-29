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

private let _fakeNowLock = NSObject()
private var _fakeNow: Double?
private var fakeNow: Double?
    {
    get {
        objc_sync_enter(_fakeNowLock)
        defer { objc_sync_exit(_fakeNowLock) }
        return _fakeNow
        }
    set {
        objc_sync_enter(_fakeNowLock)
        defer { objc_sync_exit(_fakeNowLock) }
        _fakeNow = newValue
        }
    }


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

        beforeSuite { LSNocilla.sharedInstance().start() }
        afterSuite  { LSNocilla.sharedInstance().stop() }
        afterEach   { LSNocilla.sharedInstance().clearStubs() }

        let realNow = Siesta.now
        Siesta.now =
            {
            return fakeNow ?? realNow()
            }
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

    private func runSpecsWithService(_ serviceBuilder: @escaping () -> Service)
        {
        weak var weakService: Service?

        // Standard service and resource test instances
        // (These use configurable net provider and embed the spec name in the baseURL.)

        let service = specVar
            {
            () -> Service in

            let result = serviceBuilder()
            weakService = result
            return result
            }

        let resource = specVar
            { service().resource("/a/b") }

        // Make sure that Service is deallocated after each spec (which also catches Resource and Request leaks,
        // since they ultimately retain their associated service)
        //
        // NB: This must come _after_ the specVars above, which use afterEach to clear the service and resource.

        aroundEach
            {
            example in
            autoreleasepool { example() }  // Alamofire relies on autorelease, so each spec needs its own pool for leak checking
            }

        afterEach
            {
            exampleMetadata in

            for attempt in 0...
                {
                if weakService == nil
                    { break }  // yay!

                if attempt > 4
                    {
                    fail("Service instance leaked by test")
                    weakService = nil
                    break
                    }

                if attempt > 0  // waiting for one cleanup cycle is normal
                    {
                    print("Test may have leaked service instance; will wait for cleanup and check again (attempt \(attempt))")
                    Thread.sleep(forTimeInterval: 0.02 * pow(3, Double(attempt)))
                    }
                awaitObserverCleanup()
                weakService?.flushUnusedResources()
                }
            }

        // Run the actual specs

        context("")  // Make specVars above run in a separate context so their afterEach cleans up _before_ the leak check
            {
            resourceSpec(service, resource)
            }
        }

    var baseURL: String
        {
        // Embedding the spec name in the API’s URL makes it easier to track down unstubbed requests, which sometimes
        // don’t arrive until a following spec has already started.

        return "https://" + QuickSpec.current.description
            .replacing(regex: "_[A-Za-z]+Specswift_\\d+\\]$", with: "")
            .replacing(regex: "[^A-Za-z0-9_]+", with: ".")
            .replacing(regex: "^\\.+|\\.+$", with: "")
        }
    }


// MARK: - Request stubbing

@discardableResult
func stubRequest(_ resource: () -> Resource, _ method: String) -> LSStubRequestDSL
    {
    return stubRequest(resource(), method)
    }

@discardableResult
func stubRequest(_ resource: Resource, _ method: String) -> LSStubRequestDSL
    {
    return stubRequest(method, resource.url.absoluteString as NSString)
    }

func awaitNewData(_ req: Siesta.Request, initialState: RequestState = .inProgress)
    {
    expect(req.state) == initialState
    let responseExpectation = QuickSpec.current.expectation(description: "awaiting response callback: \(req)")
    let successExpectation = QuickSpec.current.expectation(description: "awaiting success callback: \(req)")
    let newDataExpectation = QuickSpec.current.expectation(description: "awaiting newData callback: \(req)")
    req.onCompletion  { _ in responseExpectation.fulfill() }
       .onSuccess     { _ in successExpectation.fulfill() }
       .onFailure     { _ in fail("error callback should not be called") }
       .onNewData     { _ in newDataExpectation.fulfill() }
       .onNotModified { fail("notModified callback should not be called") }
    QuickSpec.current.waitForExpectations(timeout: 1)
    expect(req.state) == .completed
    }

func awaitNotModified(_ req: Siesta.Request)
    {
    expect(req.state) == .inProgress
    let responseExpectation = QuickSpec.current.expectation(description: "awaiting response callback: \(req)")
    let successExpectation = QuickSpec.current.expectation(description: "awaiting success callback: \(req)")
    let notModifiedExpectation = QuickSpec.current.expectation(description: "awaiting notModified callback: \(req)")
    req.onCompletion  { _ in responseExpectation.fulfill() }
       .onSuccess     { _ in successExpectation.fulfill() }
       .onFailure     { _ in fail("error callback should not be called") }
       .onNewData     { _ in fail("newData callback should not be called") }
       .onNotModified { notModifiedExpectation.fulfill() }
    QuickSpec.current.waitForExpectations(timeout: 1)
    expect(req.state) == .completed
    }

func awaitFailure(_ req: Siesta.Request, initialState: RequestState = .inProgress)
    {
    expect(req.state) == initialState
    let responseExpectation = QuickSpec.current.expectation(description: "awaiting response callback: \(req)")
    let errorExpectation = QuickSpec.current.expectation(description: "awaiting failure callback: \(req)")
    req.onCompletion  { _ in responseExpectation.fulfill() }
       .onFailure     { _ in errorExpectation.fulfill() }
       .onSuccess     { _ in fail("success callback should not be called") }
       .onNewData     { _ in fail("newData callback should not be called") }
       .onNotModified { fail("notModified callback should not be called") }

    QuickSpec.current.waitForExpectations(timeout: 1)
    expect(req.state) == .completed

    // When cancelling a request, Siesta immediately kills its end of the request, then sends a cancellation to the
    // network layer without waiting for a response. This causes spurious spec failures if LSNocilla’s clearStubs() gets
    // called before the network has a chance to finish, so we have to wait for the underlying request as well as Siesta.

    if initialState == .completed
        { awaitUnderlyingNetworkRequest(req) }
    }

func awaitUnderlyingNetworkRequest(_ req: Siesta.Request)
    {
    let networkExpectation = QuickSpec.current.expectation(description: "awaiting underlying network response: \(req)")
    pollUnderlyingCompletion(req, expectation: networkExpectation)
    QuickSpec.current.waitForExpectations(timeout: 1.0)
    }

private func pollUnderlyingCompletion(_ req: Siesta.Request, expectation: XCTestExpectation)
    {
    if req.state == .completed
        { expectation.fulfill() }
    else
        {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0001)
            { pollUnderlyingCompletion(req, expectation: expectation) }
        }
    }

func stubAndAwaitRequest(for resource: Resource, expectSuccess: Bool = true)
    {
    _ = stubRequest(resource, "GET").andReturn(200).withBody("🍕" as NSString)
    let awaitRequest = expectSuccess ? awaitNewData : awaitFailure
    awaitRequest(resource.load(), .inProgress)
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
//
func awaitObserverCleanup(for resource: Resource? = nil)
    {
    let cleanupExpectation = QuickSpec.current.expectation(description: "awaitObserverCleanup")
    DispatchQueue.main.async
        { cleanupExpectation.fulfill() }
    QuickSpec.current.waitForExpectations(timeout: 1)
    }

// Request cancellation can cause a race condition in specs:
//
// 1. Network request starts chugging
// 2. Request is cancelled on the Siesta side, but background network machinery already in motion
// 3. Spec completes, we clear Nocilla stubs
// 4. Request (which still hasn't received the cancellation) hits Nocilla, causing it to throw
//    an unstubbed request error
//
// Nocilla doesn't provide any way to actually guard against this, or to wait for pending requests
// to finish, so we solve it with a timeout (pending a better network stubbing lib).
//
func awaitCancelledRequests()
    {
    Thread.sleep(forTimeInterval: 0.1)
    }
