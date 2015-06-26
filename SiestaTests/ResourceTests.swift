//
//  ResourceTests.swift
//  Siesta
//
//  Created by Paul on 2015/6/20.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Siesta
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
        
        let service  = lazy { Service(base: "https://zingle.frotz/v1") },
            resource = lazy { service().resource("/a/b") }
        
        func stubResourceReqest(method: String) -> LSStubRequestDSL
            {
            return stubRequest(method, resource().url!.absoluteString)
            }
        
        func awaitResponse(req: Request)
            {
            let expectation = QuickSpec.current().expectationWithDescription("network call: \(req)")
            req.response { _ in expectation.fulfill() }
            QuickSpec.current().waitForExpectationsWithTimeout(0.1, handler: nil)
            }
        
        it("starts in a blank state")
            {
            expect(resource().data).to(beNil())
            expect(resource().latestData).to(beNil())
            expect(resource().latestError).to(beNil())
            
            expect(resource().loading).to(beFalse())
            expect(resource().requests).to(equal([]))
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
            
            it("marks that the resource is loading")
                {
                expect(resource().loading).to(beFalse())
                
                stubResourceReqest("GET").andReturn(200)
                let req = resource().request(.GET)
                expect(resource().loading).to(beTrue())
                
                awaitResponse(req)
                expect(resource().loading).to(beFalse())
                }
            
            it("tracks concurrent requests")
                {
                service().sessionManager.startRequestsImmediately = false
                defer { service().sessionManager.startRequestsImmediately = true }
                
                stubResourceReqest("GET").andReturn(200)
                let req0 = resource().request(.GET),
                    req1 = resource().request(.GET)
                expect(resource().loading).to(beTrue())
                expect(resource().requests).to(equal([req0, req1]))
                
                req0.resume()
                awaitResponse(req0)
                expect(resource().loading).to(beTrue())
                expect(resource().requests).to(equal([req1]))
                
                req1.resume()
                awaitResponse(req1)
                expect(resource().loading).to(beFalse())
                expect(resource().requests).to(equal([]))
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
