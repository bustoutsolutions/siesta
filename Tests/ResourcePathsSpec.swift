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
            func expectChild(childPath: String, toResolveTo url: String)
                { expect((resource(), childPath)).to(expandToChildURL(url)) }
            
            it("returns a resource with the same service")
                {
                expect(resource().child("c").service).to(equal(service()))
                }
                
            it("resolves bare paths as subpaths")
                {
                expectChild("c",                  toResolveTo: "https://zingle.frotz/v1/a/b/c")
                }
            
            it("resolves paths with / prefix as subpaths")
                {
                expectChild("c",                  toResolveTo: "https://zingle.frotz/v1/a/b/c")
                }
            
            it("does not resolve ./ or ../")
                {
                expectChild("./c",                toResolveTo: "https://zingle.frotz/v1/a/b/./c")
                expectChild("./c/./d",            toResolveTo: "https://zingle.frotz/v1/a/b/./c/./d")
                expectChild("../c",               toResolveTo: "https://zingle.frotz/v1/a/b/../c")
                }
            
            it("treats URL-like strings as paths")
                {
                expectChild("//other.host/c",     toResolveTo: "https://zingle.frotz/v1/a/b//other.host/c")
                expectChild("ftp://other.host/c", toResolveTo: "https://zingle.frotz/v1/a/b/ftp://other.host/c")
                }

            it("escapes characters when necessary")
                {
                expectChild("?foo",               toResolveTo: "https://zingle.frotz/v1/a/b/%3Ffoo")
                expectChild(" •⇶",                toResolveTo: "https://zingle.frotz/v1/a/b/%20%E2%80%A2%E2%87%B6")
                }
            }
            
        describe("relative()")
            {
            func expectRelative(childPath: String, toResolveTo url: String)
                { expect((resource(), childPath)).to(expandToRelativeURL(url)) }
            
            it("returns a resource with the same service")
                {
                expect(resource().relative("c").service).to(equal(service()))
                }
                
            it("treats bare paths like ./")
                {
                expectRelative("c",                  toResolveTo: "https://zingle.frotz/v1/a/c")
                }
            
            it("resolves ./")
                {
                expectRelative("./c",                toResolveTo: "https://zingle.frotz/v1/a/c")
                expectRelative("././c",              toResolveTo: "https://zingle.frotz/v1/a/c")
                expectRelative("./c/./d",            toResolveTo: "https://zingle.frotz/v1/a/c/d")
                }
            
            it("resolves ../")
                {
                expectRelative("../c",               toResolveTo: "https://zingle.frotz/v1/c")
                expectRelative("../../c",            toResolveTo: "https://zingle.frotz/c")
                expectRelative("../c/../d",          toResolveTo: "https://zingle.frotz/v1/d")
                }
            
            it("resolves absolute paths relative to host root")
                {
                expectRelative("/c",                 toResolveTo: "https://zingle.frotz/c")
                }
            
            it("resolves full URLs")
                {
                expectRelative("//other.host/c",     toResolveTo: "https://other.host/c")
                expectRelative("ftp://other.host/c", toResolveTo: "ftp://other.host/c")
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
                expect(resource().withParam("foo", "bar").url?.absoluteString)
                    .to(equal("https://zingle.frotz/v1/a/b?foo=bar"))
                }

            it("escapes params")
                {
                expect(resource().withParam("fo=o", "ba r").url?.absoluteString)
                    .to(equal("https://zingle.frotz/v1/a/b?fo%3Do=ba%20r"))
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
