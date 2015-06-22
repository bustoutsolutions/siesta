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
        
        it("does a Alamofire + Nocilla sanity check") // TODO: remove
            {
            stubRequest("GET", "https://zingle.frotz/v1")
                .andReturn(200)
                .withBody("hello")
            
            let expectation = QuickSpec.current().expectationWithDescription("network call")
            let req = Alamofire.request(.GET, URLString: "https://zingle.frotz/v1")
            req.response
                { (request, response, data, error) in
                print("\n\n ------> got response to test network call: \(data)\n\n")
                }
            req.response { _ in expectation.fulfill() }
            QuickSpec.current().waitForExpectationsWithTimeout(0.1, handler: nil)
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
