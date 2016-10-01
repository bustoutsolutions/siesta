//
//  ResourcePathsSpec.swift
//  Siesta
//
//  Created by Paul on 2015/7/5.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble
import Nocilla

class ResourcePathsSpec: ResourceSpecBase
    {
    override var baseURL: String
        { return "https://zingle.frotz/v1" }

    override func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource)
        {
        describe("child()")
            {
            func expectChild(_ childPath: String, toResolveTo url: String)
                { expect((resource(), childPath)).to(expandToChildURL(url)) }

            it("returns a resource with the same service")
                {
                expect(resource().child("c").service) == service()
                }

            it("resolves empty string as root")
                {
                expectChild("",                   toResolveTo: "https://zingle.frotz/v1/a/b/")
                }

            it("resolves bare paths as subpaths")
                {
                expectChild("c",                  toResolveTo: "https://zingle.frotz/v1/a/b/c")
                }

            it("resolves paths with / prefix as subpaths")
                {
                expectChild("/",                  toResolveTo: "https://zingle.frotz/v1/a/b/")
                expectChild("/c",                 toResolveTo: "https://zingle.frotz/v1/a/b/c")
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
            func expectRelativeOf(_ resource: Resource, _ childPath: String, toResolveTo url: String)
                { expect((resource, childPath)).to(expandToRelativeURL(url)) }

            func expectRelative(_ childPath: String, toResolveTo url: String)
                { expectRelativeOf(resource(), childPath, toResolveTo: url) }

            it("returns a resource with the same service")
                {
                expect(resource().relative("c").service) == service()
                }

            it("treats bare paths as if they are preceded by ./")
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

            it("can add a query string")
                {
                expectRelative("?foo=1",             toResolveTo: "https://zingle.frotz/v1/a/b?foo=1")
                expectRelative("c?foo=1",            toResolveTo: "https://zingle.frotz/v1/a/c?foo=1")
                }

            it("does not alphabetize query string params, unlike withParam(_:_:)")
                {
                expectRelative("?foo=1&bar=2",       toResolveTo: "https://zingle.frotz/v1/a/b?foo=1&bar=2")
                expectRelative("c?foo=1&bar=2",      toResolveTo: "https://zingle.frotz/v1/a/c?foo=1&bar=2")
                }

            it("entirely replaces or removes an existing query string")
                {
                let resourceWithParam = resource().withParam("foo", "bar")
                expectRelativeOf(resourceWithParam, "?baz=fez", toResolveTo: "https://zingle.frotz/v1/a/b?baz=fez")
                expectRelativeOf(resourceWithParam, "./c",      toResolveTo: "https://zingle.frotz/v1/a/c")
                }
            }

        describe("optionalRelative()")
            {
            it("works like relative() if arg is present")
                {
                expect(resource().optionalRelative("c")) === resource().relative("c")
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
                expect(resource().withParam("foo", "bar").url.absoluteString)
                     == "https://zingle.frotz/v1/a/b?foo=bar"
                }

            it("escapes params")
                {
                expect(resource().withParam("fo=o", "ba r+baz").url.absoluteString)
                     == "https://zingle.frotz/v1/a/b?fo%3Do=ba%20r%2Bbaz"
                }

            let resourceWithParams = specVar { resource().withParam("foo", "bar").withParam("zoogle", "oogle") }

            it("alphabetizes params (to help with resource uniqueness)")
                {
                expect(resourceWithParams().withParam("plop", "blop").url.absoluteString)
                     == "https://zingle.frotz/v1/a/b?foo=bar&plop=blop&zoogle=oogle"
                }

            it("modifies existing params without affecting others")
                {
                expect(resourceWithParams().withParam("zoogle", "zonk").url.absoluteString)
                     == "https://zingle.frotz/v1/a/b?foo=bar&zoogle=zonk"
                }

            it("treats empty string value as empty param")
                {
                expect(resourceWithParams().withParam("foo", "").url.absoluteString)
                     == "https://zingle.frotz/v1/a/b?foo&zoogle=oogle"
                }

            it("treats nil value as removal")
                {
                expect(resourceWithParams().withParam("foo", nil).url.absoluteString)
                     == "https://zingle.frotz/v1/a/b?zoogle=oogle"
                }

            it("drops query string if all params removed")
                {
                expect(resourceWithParams().withParam("foo", nil).withParam("zoogle", nil).url.absoluteString)
                     == "https://zingle.frotz/v1/a/b"
                }
            }
        }
    }


// MARK: - Custom matchers

private func resourceExpansionMatcher(
             _ expectedURL: String,
        relationshipName: String,
            relationship: @escaping (Resource,String) -> Resource)
    -> MatcherFunc<(Resource,String)>
    {
    return MatcherFunc
        { inputs, failureMessage in

        let (resource, path) = try! inputs.evaluate()!,
            actualURL = relationship(resource, path).url.absoluteString
        failureMessage.stringValue =
            "expected \(relationshipName) \(path.debugDescription)"
            + " of resource \(resource.url)"
            + " to expand to \(expectedURL.debugDescription),"
            + " but got \(actualURL.debugDescription)"
        return actualURL == expectedURL
        }
    }

private func expandToChildURL(_ expectedURL: String) -> MatcherFunc<(Resource,String)>
    {
    return resourceExpansionMatcher(expectedURL, relationshipName: "child")
        { resource, path in resource.child(path) }
    }

private func expandToRelativeURL(_ expectedURL: String) -> MatcherFunc<(Resource,String)>
    {
    return resourceExpansionMatcher(expectedURL, relationshipName: "relative")
        { resource, path in resource.relative(path) }
    }
