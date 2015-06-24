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
        
        let stubResourceReqest =
            {
            (method: String, resultCode: Int) in
            return stubRequest(method, resource().url!.absoluteString)
                .andReturn(resultCode)
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
            expect(resource().state.latestData).to(beNil())
            expect(resource().state.latestError).to(beNil())
            
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
                stubResourceReqest("GET", 200)
                awaitResponse(resource().request(.GET))
                }
            
            it("handles various HTTP methods")
                {
                stubResourceReqest("PATCH", 200)
                awaitResponse(resource().request(.PATCH))
                }
            
            it("marks that the resource is loading")
                {
                expect(resource().loading).to(beFalse())
                
                stubResourceReqest("GET", 200)
                let req = resource().request(.GET)
                expect(resource().loading).to(beTrue())
                
                awaitResponse(req)
                expect(resource().loading).to(beFalse())
                }
            
            it("tracks concurrent requests")
                {
                service().sessionManager.startRequestsImmediately = false
                defer { service().sessionManager.startRequestsImmediately = true }
                
                stubResourceReqest("GET", 200)
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
                stubResourceReqest("GET", 200)
                awaitResponse(resource().request(.GET))
                expect(resource().state.latestData).to(beNil())
                expect(resource().state.latestError).to(beNil())
                }
            }

        describe("load()")
            {
            it("stores the response data")
                {
                stubResourceReqest("GET", 200)
                    .withBody("eep eep")
                awaitResponse(resource().load())
                
                expect(resource().state.latestData).notTo(beNil())
                expect(dataAsString(resource().data)).to(equal("eep eep"))
                }
            
            it("stores the content type")
                {
                stubResourceReqest("GET", 200)
                    .withHeader("cOnTeNt-TyPe", "text/monkey")
                awaitResponse(resource().load())
                
                expect(resource().state.latestData?.mimeType).to(equal("text/monkey"))
                }
            
            it("defaults content type to raw binary")
                {
                stubResourceReqest("GET", 200)
                awaitResponse(resource().load())
                
                expect(resource().state.latestData?.mimeType).to(equal("application/octet-stream"))
                }
                
            it("stores the etag")
                {
                stubResourceReqest("GET", 200).withHeader("eTaG", "123 456 xyz")
                awaitResponse(resource().load())
                
                expect(resource().state.latestData?.etag).to(equal("123 456 xyz"))
                }
            
            it("handles missing etag")
                {
                stubResourceReqest("GET", 200)
                awaitResponse(resource().load())
                
                expect(resource().state.latestData?.etag).to(beNil())
                }
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
