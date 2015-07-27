//
//  ResourcePathsSpec.swift
//  Siesta
//
//  Created by Paul on 2015/7/5.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble
import Nocilla

class ResourcePathsSpec: ResourceSpecBase
    {
    override func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        {
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

        describe("optionalRelative()")
            {
            it("works like relative() if arg is present")
                {
                expect(resource().optionalRelative("c")).to(beIdenticalTo(resource().relative("c")))
                }

            it("returns nil if arg is absent")
                {
                expect(resource().optionalRelative(nil)).to(beNil())
                }
            }

        describe("withParam()")
            {
            it("adds params")
                {
                expect(resource().withParam("foo", "bar").url?.absoluteString).to(equal("https://zingle.frotz/v1/a/b?foo=bar"))
                }

            it("escapes params")
                {
                expect(resource().withParam("fo=o", "ba r").url?.absoluteString).to(equal("https://zingle.frotz/v1/a/b?fo%3Do=ba%20r"))
                }
                
            let resourceWithParams = specVar { resource().withParam("foo", "bar").withParam("zoogle", "oogle") }
            
            it("alphabetizes params (to help with resource uniqueness)")
                {
                expect(resourceWithParams().withParam("plop", "blop").url?.absoluteString)
                    .to(equal("https://zingle.frotz/v1/a/b?foo=bar&plop=blop&zoogle=oogle"))
                }
                
            it("modifies existing params without affecting others")
                {
                expect(resourceWithParams().withParam("zoogle", "zonk").url?.absoluteString)
                    .to(equal("https://zingle.frotz/v1/a/b?foo=bar&zoogle=zonk"))
                }
                
            it("treats nil value as removal")
                {
                expect(resourceWithParams().withParam("foo", nil).url?.absoluteString)
                    .to(equal("https://zingle.frotz/v1/a/b?zoogle=oogle"))
                }
                
            it("drops query string if all params removed")
                {
                expect(resourceWithParams().withParam("foo", nil).withParam("zoogle", nil).url?.absoluteString)
                    .to(equal("https://zingle.frotz/v1/a/b"))
                }
            }
        }
    }


// MARK: - Custom matchers

private func resourceExpansionMatcher(
             expectedURL: String,
        relationshipName: String,
            relationship: (Resource,String) -> Resource)
    -> MatcherFunc<(Resource,String)>
    {
    return MatcherFunc
        { inputs, failureMessage in
        
        let (resource, path) = try! inputs.evaluate()!,
            actualURL = relationship(resource, path).url?.absoluteString
        failureMessage.stringValue =
            "expected \(relationshipName) \(path.debugDescription)"
            + " of resource \(resource.url)"
            + " to expand to \(expectedURL.debugDescription),"
            + " but got \(actualURL.debugDescription)"
        return actualURL == expectedURL
        }
    }

private func expandToChildURL(expectedURL: String) -> MatcherFunc<(Resource,String)>
    {
    return resourceExpansionMatcher(expectedURL, relationshipName: "child")
        { resource, path in resource.child(path) }
    }

private func expandToRelativeURL(expectedURL: String) -> MatcherFunc<(Resource,String)>
    {
    return resourceExpansionMatcher(expectedURL, relationshipName: "relative")
        { resource, path in resource.relative(path) }
    }
