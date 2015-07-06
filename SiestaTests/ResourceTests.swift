//
//  ResourceTests.swift
//  Siesta
//
//  Created by Paul on 2015/6/20.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

@testable import Siesta
import Quick
import Nimble
import Nocilla
import Alamofire

class ResourceTests: QuickSpec
    {
    override func spec()
        {
        beforeSuite { LSNocilla.sharedInstance().start() }
        afterSuite  { LSNocilla.sharedInstance().stop() }
        afterEach   { LSNocilla.sharedInstance().clearStubs() }
        
        var originalNowProvider = now
        beforeEach { originalNowProvider = now }
        afterEach  { now = originalNowProvider }
        
        let service  = specVar { Service(base: "https://zingle.frotz/v1") },
            resource = specVar { service().resource("/a/b") }
        
        func stubResourceReqest(method: String) -> LSStubRequestDSL
            {
            return stubRequest(method, resource().url!.absoluteString)
            }
        
        func awaitResponse(req: Request)
            {
            let expectation = QuickSpec.current().expectationWithDescription("network call: \(req)")
            req.response { _ in expectation.fulfill() }
            QuickSpec.current().waitForExpectationsWithTimeout(1, handler: nil)
            }
        
        it("starts in a blank state")
            {
            expect(resource().data).to(beNil())
            expect(resource().latestData).to(beNil())
            expect(resource().latestError).to(beNil())
            
            expect(resource().loading).to(beFalse())
            expect(resource().loadRequests).to(equal([]))
            }
        
        describe("child()")
            {
            it("returns a resource with the same service")
                {
                expect(resource().child("c").service).to(equal(service()))
                }
                
            it("resolves bare paths as subpaths")
                {
                expect((resource(), "c")).to(expandToChildURL("https://zingle.frotz/v1/a/b/c"))
                }
            
            it("resolves paths with / prefix as subpaths")
                {
                expect((resource(), "c")).to(expandToChildURL("https://zingle.frotz/v1/a/b/c"))
                }
            
            it("does not resolve ./ or ../")
                {
                expect((resource(), "./c")).to(expandToChildURL("https://zingle.frotz/v1/a/b/./c"))
                expect((resource(), "./c/./d")).to(expandToChildURL("https://zingle.frotz/v1/a/b/./c/./d"))
                expect((resource(), "../c")).to(expandToChildURL("https://zingle.frotz/v1/a/b/../c"))
                }
            
            it("treats URL-like strings as paths")
                {
                expect((resource(), "//other.host/c")).to(expandToChildURL("https://zingle.frotz/v1/a/b//other.host/c"))
                expect((resource(), "ftp://other.host/c")).to(expandToChildURL("https://zingle.frotz/v1/a/b/ftp://other.host/c"))
                }
            }
            
        describe("relative()")
            {
            it("returns a resource with the same service")
                {
                expect(resource().relative("c").service).to(equal(service()))
                }
                
            it("treats bare paths like ./")
                {
                expect((resource(), "c")).to(expandToRelativeURL("https://zingle.frotz/v1/a/c"))
                }
            
            it("resolves ./")
                {
                expect((resource(), "./c")).to(expandToRelativeURL("https://zingle.frotz/v1/a/c"))
                expect((resource(), "././c")).to(expandToRelativeURL("https://zingle.frotz/v1/a/c"))
                expect((resource(), "./c/./d")).to(expandToRelativeURL("https://zingle.frotz/v1/a/c/d"))
                }
            
            it("resolves ../")
                {
                expect((resource(), "../c")).to(expandToRelativeURL("https://zingle.frotz/v1/c"))
                expect((resource(), "../../c")).to(expandToRelativeURL("https://zingle.frotz/c"))
                expect((resource(), "../c/../d")).to(expandToRelativeURL("https://zingle.frotz/v1/d"))
                }
            
            it("resolves absolute paths relative to host root")
                {
                expect((resource(), "/c")).to(expandToRelativeURL("https://zingle.frotz/c"))
                }
            
            it("resolves full URLs")
                {
                expect((resource(), "//other.host/c")).to(expandToRelativeURL("https://other.host/c"))
                expect((resource(), "ftp://other.host/c")).to(expandToRelativeURL("ftp://other.host/c"))
                }
            }
        
        describe("request()")
            {
            it("fetches the resource")
                {
                stubResourceReqest("GET").andReturn(200)
                awaitResponse(resource().request(.GET))
                }
            
            it("handles various HTTP methods")
                {
                stubResourceReqest("PATCH").andReturn(200)
                awaitResponse(resource().request(.PATCH))
                }
            
            it("does not mark that the resource is loading")
                {
                expect(resource().loading).to(beFalse())
                
                stubResourceReqest("GET").andReturn(200)
                let req = resource().request(.GET)
                expect(resource().loading).to(beFalse())
                
                awaitResponse(req)
                expect(resource().loading).to(beFalse())
                }

            it("does not update the resource state")
                {
                stubResourceReqest("GET").andReturn(200)
                awaitResponse(resource().request(.GET))
                expect(resource().latestData).to(beNil())
                expect(resource().latestError).to(beNil())
                }
            }

        describe("load()")
            {
            it("marks that the resource is loading")
                {
                expect(resource().loading).to(beFalse())
                
                stubResourceReqest("GET").andReturn(200)
                let req = resource().load()
                expect(resource().loading).to(beTrue())
                
                awaitResponse(req)
                expect(resource().loading).to(beFalse())
                }
            
            it("tracks concurrent requests")
                {
                service().sessionManager.startRequestsImmediately = false
                defer { service().sessionManager.startRequestsImmediately = true }
                
                stubResourceReqest("GET").andReturn(200)
                let req0 = resource().load(),
                    req1 = resource().load()
                expect(resource().loading).to(beTrue())
                expect(resource().loadRequests).to(equal([req0, req1]))
                
                req0.resume()
                awaitResponse(req0)
                expect(resource().loading).to(beTrue())
                expect(resource().loadRequests).to(equal([req1]))
                
                req1.resume()
                awaitResponse(req1)
                expect(resource().loading).to(beFalse())
                expect(resource().loadRequests).to(equal([]))
                }
            
            it("stores the response data")
                {
                stubResourceReqest("GET").andReturn(200)
                    .withBody("eep eep")
                awaitResponse(resource().load())
                
                expect(resource().latestData).notTo(beNil())
                expect(dataAsString(resource().data)).to(equal("eep eep"))
                }
            
            it("stores the content type")
                {
                stubResourceReqest("GET").andReturn(200)
                    .withHeader("cOnTeNt-TyPe", "text/monkey")
                awaitResponse(resource().load())
                
                expect(resource().latestData?.mimeType).to(equal("text/monkey"))
                }
            
            it("defaults content type to raw binary")
                {
                stubResourceReqest("GET").andReturn(200)
                awaitResponse(resource().load())
                
                expect(resource().latestData?.mimeType).to(equal("application/octet-stream"))
                }
                
            it("handles missing etag")
                {
                stubResourceReqest("GET").andReturn(200)
                awaitResponse(resource().load())
                
                expect(resource().latestData?.etag).to(beNil())
                }
            
            func sendAndWaitForSuccessfulRequest()
                {
                stubResourceReqest("GET")
                    .andReturn(200)
                    .withHeader("eTaG", "123 456 xyz")
                    .withHeader("Content-Type", "applicaiton/zoogle+plotz")
                    .withBody("zoogleplotz")
                awaitResponse(resource().load())
                LSNocilla.sharedInstance().clearStubs()
                }
            
            func expectDataToBeUnchanged()
                {
                expect(dataAsString(resource().data)).to(equal("zoogleplotz"))
                expect(resource().latestData?.mimeType).to(equal("applicaiton/zoogle+plotz"))
                expect(resource().latestData?.etag).to(equal("123 456 xyz"))
                }
            
            context("receiving an etag")
                {
                beforeEach(sendAndWaitForSuccessfulRequest)
                
                it("stores the etag")
                    {
                    expect(resource().latestData?.etag).to(equal("123 456 xyz"))
                    }
                
                it("sends the etag with subsequent requests")
                    {
                    stubResourceReqest("GET")
                        .withHeader("If-None-Match", "123 456 xyz")
                        .andReturn(304)
                    awaitResponse(resource().load())
                    }
                
                it("handles subsequent 200 by replacing data")
                    {
                    stubResourceReqest("GET")
                        .andReturn(200)
                        .withHeader("eTaG", "ABC DEF 789")
                        .withHeader("Content-Type", "applicaiton/ploogle+zotz")
                        .withBody("plooglezotz")
                    awaitResponse(resource().load())
                        
                    expect(dataAsString(resource().data)).to(equal("plooglezotz"))
                    expect(resource().latestData?.mimeType).to(equal("applicaiton/ploogle+zotz"))
                    expect(resource().latestData?.etag).to(equal("ABC DEF 789"))
                    }
                
                it("handles subsequent 304 by keeping existing data")
                    {
                    stubResourceReqest("GET").andReturn(304)
                    awaitResponse(resource().load())
                    
                    expectDataToBeUnchanged()
                    expect(resource().latestError).to(beNil())
                    }
                }
            
            it("handles request errors")
                {
                let sampleError = NSError(domain: "TestDomain", code: 12345, userInfo: nil)
                stubResourceReqest("GET").andFailWithError(sampleError)
                awaitResponse(resource().load())
                
                expect(resource().latestData).to(beNil())
                expect(resource().latestError).notTo(beNil())
                expect(resource().latestError?.nsError).to(equal(sampleError))
                }
            
            // Testing all these HTTP codes individually because Apple likes
            // to treat specific ones as special cases.
            
            for statusCode in Array(400...410) + (500...505)
                {
                it("treats HTTP \(statusCode) as an error")
                    {
                    stubResourceReqest("GET").andReturn(statusCode)
                    awaitResponse(resource().load())
                    
                    expect(resource().latestData).to(beNil())
                    expect(resource().latestError).notTo(beNil())
                    expect(resource().latestError?.httpStatusCode).to(equal(statusCode))
                    }
                }
            
            it("preserves last valid data after error")
                {
                sendAndWaitForSuccessfulRequest()

                stubResourceReqest("GET").andReturn(500)
                awaitResponse(resource().load())
                
                expectDataToBeUnchanged()
                }

            it("leaves everything unchanged after a cancelled request")  // TODO: should be separate instead?
                {
                sendAndWaitForSuccessfulRequest()
                
                let req = resource().load()
                req.cancel()
                awaitResponse(req)

                expectDataToBeUnchanged()
                expect(resource().latestError).to(beNil())
                }
            
            // TODO: test no internet connnection if possible
            
            it("generates error messages from NSError message")
                {
                let sampleError = NSError(
                    domain: "TestDomain", code: 12345,
                    userInfo: [NSLocalizedDescriptionKey: "KABOOM"])
                stubResourceReqest("GET").andFailWithError(sampleError)
                awaitResponse(resource().load())
                
                expect(resource().latestError?.userMessage).to(equal("KABOOM"))
                }
            
            it("generates error messages from HTTP status codes")
                {
                stubResourceReqest("GET").andReturn(404)
                awaitResponse(resource().load())
                
                expect(resource().latestError?.userMessage).to(equal("Server error: not found"))
                }
            
            // TODO: support custom error message extraction
            
            // TODO: how should it handle redirects?
            }
        
        describe("loadIfNeeded()")
            {
            func expectToLoad(req: Request?)
                {
                expect(req).notTo(beNil())
                expect(resource().loading).to(beTrue())
                stubResourceReqest("GET").andReturn(200)
                awaitResponse(resource().load())
                }
            
            func expectNotToLoad(req: Request?)
                {
                expect(req).to(beNil())
                expect(resource().loading).to(beFalse())
                }
            
            it("loads a resource never before loaded")
                {
                expectToLoad(resource().loadIfNeeded())
                }
            
            context("with data present")
                {
                beforeEach
                    {
                    now = { 1000 }
                    expectToLoad(resource().load())
                    }
                
                it("does not load again soon")
                    {
                    now = { 1010 }
                    expectNotToLoad(resource().loadIfNeeded())
                    }
                
                it("loads again later")
                    {
                    now = { 2000 }
                    expectToLoad(resource().loadIfNeeded())
                    }
                
                it("respects custom expiration time")
                    {
                    now = { 1002 }
                    resource().expirationTime = 1
                    expectToLoad(resource().loadIfNeeded())
                    }
                }
            
            context("with an error present")
                {
                beforeEach
                    {
                    now = { 1000 }
                    stubResourceReqest("GET").andReturn(404)
                    awaitResponse(resource().load())
                    }
                
                it("does not retry soon")
                    {
                    now = { 1001 }
                    expectNotToLoad(resource().loadIfNeeded())
                    }
                
                it("retries later")
                    {
                    now = { 2000 }
                    expectToLoad(resource().loadIfNeeded())
                    }
                
                it("respects custom retry time")
                    {
                    now = { 1002 }
                    resource().retryTime = 1
                    expectToLoad(resource().loadIfNeeded())
                    }
                }
            }
        
        describe("observer")
            {
            let observer = specVar { TestObserverWithExpectations() }
            
            beforeEach
                {
                observer().expect(.OBSERVER_ADDED)
                resource().addObserver(observer())
                }
            
            it("receives a notification that it was added")
                {
                let observer2 = TestObserverWithExpectations()
                observer2.expect(.OBSERVER_ADDED)  // only for new observer
                resource().addObserver(observer2)
                }
            
            it("receives request event")
                {
                stubResourceReqest("GET").andReturn(200)
                observer().expect(.REQUESTED)
                    {
                    expect(resource().loading).to(beTrue())
                    expect(resource().latestData).to(beNil())
                    expect(resource().latestError).to(beNil())
                    }
                let req = resource().load()
                
                // Let Nocilla check off request without any further observing
                resource().removeObservers(ownedBy: observer())
                awaitResponse(req)
                }
            
            it("receives new data event")
                {
                stubResourceReqest("GET").andReturn(200)
                observer().expect(.REQUESTED)
                observer().expect(.NEW_DATA_RESPONSE)
                    {
                    expect(resource().loading).to(beFalse())
                    expect(resource().latestData).notTo(beNil())
                    expect(resource().latestError).to(beNil())
                    }
                awaitResponse(resource().load())
                }
            
            it("receives not modified event")
                {
                stubResourceReqest("GET").andReturn(304)
                observer().expect(.REQUESTED)
                observer().expect(.NOT_MODIFIED_RESPONSE)
                    {
                    expect(resource().loading).to(beFalse())
                    }
                awaitResponse(resource().load())
                }

            it("receives cancel event")
                {
                stubResourceReqest("GET").andReturn(200)
                observer().expect(.REQUESTED)
                observer().expect(.REQUEST_CANCELLED)
                    {
                    expect(resource().loading).to(beFalse())
                    }
                let req = resource().load()
                req.cancel()
                awaitResponse(req)
                }
            
            it("receives failure event")
                {
                stubResourceReqest("GET").andReturn(500)
                observer().expect(.REQUESTED)
                observer().expect(.ERROR_RESPONSE)
                    {
                    expect(resource().loading).to(beFalse())
                    expect(resource().latestData).to(beNil())
                    expect(resource().latestError).notTo(beNil())
                    }
                awaitResponse(resource().load())
                }
            
            it("does not receive notifications for request(), only load()")
                {
                stubResourceReqest("GET").andReturn(200)
                awaitResponse(resource().request(.GET))
                }
            }
            
        describe("memory management")
            {
            it("prevents the resource from being deallocated while it has observers")
                {
                var resource: Resource? = service().resource("zargle")
                weak var resourceWeak = resource
                let observer = TestObserver()
                resource?.addObserver(observer)
                resource = nil
                
                simulateMemoryWarning()
                expect(resourceWeak).notTo(beNil())
                
                resourceWeak?.removeObservers(ownedBy: observer)
                simulateMemoryWarning()
                expect(resourceWeak).to(beNil())
                }
            
            it("stops observing when observer is deallocated")
                {
                var observer: TestObserverWithExpectations? = TestObserverWithExpectations()
                weak var observerWeak = observer
                observer!.expect(.OBSERVER_ADDED)
                observer!.expect(.REQUESTED)
                resource().addObserver(observer!)
                
                let req = resource().load()
                observer!.checkForUnfulfilledExpectations()
                
                observer = nil
                expect(observerWeak).to(beNil())  // resource should not have retained it
                
                // No expectations, so this will fail if Resource still notifies observer
                stubResourceReqest("GET").andReturn(200)
                awaitResponse(req)
                }
            
            it("stops observing when owner is deallocated")
                {
                let observer = TestObserverWithExpectations()
                var owner: AnyObject? = "foo"
                observer.expect(.OBSERVER_ADDED)
                resource().addObserver(observer, owner: owner!)
                
                observer.expect(.REQUESTED)
                let req = resource().load()
                observer.checkForUnfulfilledExpectations()
                
                owner = nil
                stubResourceReqest("GET").andReturn(200)
                awaitResponse(req)  // make sure Resource doesn't blow up
                }
            }
        }
    }

class TestObserver: ResourceObserver
    {
    func resourceChanged(resource: Resource, event: ResourceEvent) { }
    }

class TestObserverWithExpectations: ResourceObserver
    {
    private var expectedEvents = [Expectation]()
    
    deinit
        { checkForUnfulfilledExpectations() }
    
    func expect(event: ResourceEvent, callback: (Void -> Void) = {})
        { expectedEvents.append(Expectation(event: event, callback: callback)) }
    
    func checkForUnfulfilledExpectations()
        {
        if !expectedEvents.isEmpty
            { XCTFail("Expected observer events, but never received them: \(expectedEvents.map { $0.event })") }
        }
    
    func resourceChanged(resource: Resource, event: ResourceEvent)
        {
        if expectedEvents.isEmpty
            { XCTFail("Received unexpected observer event: \(event)") }
        else
            {
            let expectation = expectedEvents.removeAtIndex(0)
            if event != expectation.event
                { XCTFail("Received unexpected observer event: \(event) (was expecting \(expectation.event))") }
            else
                { expectation.callback() }
            }
        }
    
    struct Expectation
        {
        let event: ResourceEvent
        let callback: (Void -> Void)
        
        func description() -> String
            { return "\(event)" }
        }
    }

func resourceExpansionMatcher(
             expectedURL: String,
        relationshipName: String,
            relationship: (Resource,String) -> Resource)
    -> MatcherFunc<(Resource,String)>
    {
    return MatcherFunc
        { inputs, failureMessage in
        
        let (resource, path) = inputs.evaluate()!,
            actualURL = relationship(resource, path).url?.absoluteString
        failureMessage.stringValue =
            "expected \(relationshipName) \(path.debugDescription)"
            + " of resource \(resource.url)"
            + " to expand to \(expectedURL.debugDescription),"
            + " but got \(actualURL.debugDescription)"
        return actualURL == expectedURL
        }
    }

func expandToChildURL(expectedURL: String) -> MatcherFunc<(Resource,String)>
    {
    return resourceExpansionMatcher(expectedURL, relationshipName: "child")
        { resource, path in resource.child(path) }
    }

func expandToRelativeURL(expectedURL: String) -> MatcherFunc<(Resource,String)>
    {
    return resourceExpansionMatcher(expectedURL, relationshipName: "relative")
        { resource, path in resource.relative(path) }
    }

func dataAsString(data: AnyObject?) -> String?
    {
    guard let nsdata = data as? NSData else
        { return nil }
    
    return NSString(data: nsdata, encoding: NSUTF8StringEncoding) as? String
    }
