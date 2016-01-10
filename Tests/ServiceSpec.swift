//
//  ServiceSpec.swift
//  Siesta
//
//  Created by Paul on 2015/6/14.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble

class ServiceSpec: SiestaSpec
    {
    override func spec()
        {
        super.spec()

        let service   = specVar { Service(baseURL: "https://zingle.frotz") }
        let resource0 = specVar { service().resource("/foo") },
            resource1 = specVar { service().resource("/bar") }

        describe("init()")
            {
            it("enforces a trailing slash on baseURL")
                {
                expect("http://foo.bar")     .to(expandToBaseURL("http://foo.bar/"))
                expect("http://foo.bar/")    .to(expandToBaseURL("http://foo.bar/"))
                expect("http://foo.bar/baz") .to(expandToBaseURL("http://foo.bar/baz/"))
                expect("http://foo.bar/baz/").to(expandToBaseURL("http://foo.bar/baz/"))
                }

            it("preserves baseURL query parameters")
                {
                expect("http://foo.bar?you=mysunshine")     .to(expandToBaseURL("http://foo.bar/?you=mysunshine"))
                expect("http://foo.bar/?you=mysunshine")    .to(expandToBaseURL("http://foo.bar/?you=mysunshine"))
                expect("http://foo.bar/baz?you=mysunshine") .to(expandToBaseURL("http://foo.bar/baz/?you=mysunshine"))
                expect("http://foo.bar/baz/?you=mysunshine").to(expandToBaseURL("http://foo.bar/baz/?you=mysunshine"))
                }

            context("with no baseURL")
                {
                let bareService = specVar { Service() }

                it("returns a nil baseURL")
                    {
                    expect(bareService().baseURL).to(beNil())
                    }

                it("fails requests for path-based resources")
                    {
                    expectInvalidResource(bareService().resource("foo"))
                    }

                it("fails requests for relative URLs")
                    {
                    expectInvalidResource(bareService().resource(absoluteURL: "/foo"))
                    }

                it("allows requests for absolute URLs")
                    {
                    let resource = bareService().resource(absoluteURL: "http://foo.bar")
                    stubRequest({ resource }, "GET").andReturn(200)
                    awaitNewData(resource.load())
                    }
                }
            }

        describe("resource()")
            {
            it("returns a resource that belongs to this service")
                {
                expect(service().resource("/foo").service)
                    .to(equal(service()))
                }

            it("resolves all paths as subpaths of baseURL")
                {
                // Note that checkPathExpansion tests both with & without leading slash
                checkPathExpansion("https://foo.bar",    path:"",         expect:"https://foo.bar/")
                checkPathExpansion("https://foo.bar",    path:"baz",      expect:"https://foo.bar/baz")
                checkPathExpansion("https://foo.bar",    path:"baz/fez",  expect:"https://foo.bar/baz/fez")
                checkPathExpansion("https://foo.bar",    path:"baz/fez/", expect:"https://foo.bar/baz/fez/")
                checkPathExpansion("https://foo.bar/v1", path:"baz",      expect:"https://foo.bar/v1/baz")
                checkPathExpansion("https://foo.bar/v1", path:"baz/fez",  expect:"https://foo.bar/v1/baz/fez")
                }

            it("does not apply special interpretation to . or ..")
                {
                checkPathExpansion("https://foo.bar/v1", path:"./baz",  expect:"https://foo.bar/v1/./baz")
                checkPathExpansion("https://foo.bar/v1", path:"../baz", expect:"https://foo.bar/v1/../baz")
                checkPathExpansion("https://foo.bar/v1", path:"baz/.",  expect:"https://foo.bar/v1/baz/.")
                checkPathExpansion("https://foo.bar/v1", path:"baz/..", expect:"https://foo.bar/v1/baz/..")
                }

            it("preserves baseURL query params")
                {
                checkPathExpansion("https://foo.bar/?a=b&x=y",   path:"baz/fez/", expect:"https://foo.bar/baz/fez/?a=b&x=y")
                checkPathExpansion("https://foo.bar/v1?a=b&x=y", path:"baz",      expect:"https://foo.bar/v1/baz?a=b&x=y")
                }

            it("gives a non-nil but invalid resource for invalid URLs")
                {
                expectInvalidResource(service().resource(absoluteURL: "http://[URL syntax error]"))
                expectInvalidResource(service().resource(absoluteURL: "\0"))
                expectInvalidResource(service().resource(absoluteURL: nil as NSURL?))
                expectInvalidResource(service().resource(absoluteURL: nil as String?))
                }
            }

        describe("caching")
            {
            it("gives the same Resource instance for the same path")
                {
                expect(service().resource("/foo"))
                    .to(beIdenticalTo(service().resource("/foo")))
                }

            it("gives the same Resource instance no matter how it’s constructed")
                {
                expect(service().resource("/foo").child("oogle").child("baz").relative("../bar"))
                    .to(beIdenticalTo(service().resource("/foo/bar")))
                }
            }

        describe("configuration")
            {
            it("applies global config to all resources")
                {
                service().configure { $0.config.expirationTime = 17 }
                expect(resource0().config.expirationTime).to(equal(17))
                expect(resource1().config.expirationTime).to(equal(17))
                }

            it("passes default configuration through if not overridden")
                {
                service().configure { $0.config.retryTime = 17 }
                expect(resource0().config.expirationTime).to(equal(30))
                }

            it("applies resource-specific config only to that resource")
                {
                service().configure(resource0())
                    { $0.config.expirationTime = 17 }
                expect(resource0().config.expirationTime).to(equal(17))
                expect(resource1().config.expirationTime).to(equal(30))
                }

            it("applies predicate config only to matching resources")
                {
                service().configure({ $0.absoluteString.hasSuffix("foo") })
                    { $0.config.expirationTime = 17 }
                expect(resource0().config.expirationTime).to(equal(17))
                expect(resource1().config.expirationTime).to(equal(30))
                }

            context("using wilcards")
                {
                func checkPattern(
                        pattern: String,
                        matches: Bool,
                        _ pathOrURL: String,
                        absolute: Bool = false,
                        params: [String:String] = [:],
                        service: Service  = Service(baseURL: "https://foo.bar/v1"))
                    {
                    service.configure(pattern) { $0.config.expirationTime = 6 }

                    var resource = absolute
                        ? service.resource(absoluteURL: pathOrURL)
                        : service.resource(pathOrURL)
                    for (k,v) in params
                        { resource = resource.withParam(k, v) }

                    let actual = resource.config.expirationTime,
                        expected = matches ? 6.0 : 30.0,
                        matchword = matches ? "to" : "not to"
                    XCTAssert(expected == actual, "Expected \(pattern) \(matchword) match \(pathOrURL)")
                    }

                it("matches against the base URL")
                    {
                    checkPattern("fez",  matches: true,  "/fez")
                    checkPattern("/fez", matches: true,  "/fez")
                    checkPattern("/fez", matches: false, "https://foo.com/v1/fez", absolute: true)
                    checkPattern("/fez", matches: false, "/sombrero/fez")
                    checkPattern("/fez", matches: false, "/sombrero/https://foo.bar/v1/fez")
                    }

                it("matches full URLs")
                    {
                    checkPattern("https://foo.com/*/fez", matches: false, "/fez")
                    checkPattern("https://foo.com/*/fez", matches: true,  "https://foo.com/v1/fez", absolute: true)
                    }

                it("ignores a leading slash")
                    {
                    checkPattern("hither/thither", matches: true, "/hither/thither")
                    checkPattern("/hither/thither", matches: true, "hither/thither")
                    }

                it("matches path segments with *")
                    {
                    checkPattern("/*",     matches: true,  "/hither")
                    checkPattern("/*",     matches: false, "/hither/")
                    checkPattern("/*",     matches: false, "/hither/thither")
                    checkPattern("/*b",    matches: true,  "/zub")
                    checkPattern("/*b",    matches: false, "/zu/b")
                    checkPattern("/*/b",   matches: false, "/a/")
                    checkPattern("/*/b",   matches: true,  "/a/b")
                    checkPattern("/*/b",   matches: false, "/a/b/")
                    checkPattern("/a/*/c", matches: true,  "/a/blarg/c")
                    checkPattern("/a/*/c", matches: false, "/a/c")
                    checkPattern("/*x*/c", matches: true,  "/x/c")
                    checkPattern("/*x*/c", matches: true,  "/foxy/c")
                    checkPattern("/*x*/c", matches: false, "/fozzy/c")
                    }

                it("matches across segments with **")
                    {
                    checkPattern("/**",     matches: true,  "/")
                    checkPattern("/**",     matches: true,  "/hither")
                    checkPattern("/**",     matches: true,  "/hither/thither/yon")
                    checkPattern("/a/**/b", matches: true,  "/a/b")
                    checkPattern("/a/**/b", matches: true,  "/a/1/2/3/b")
                    checkPattern("/a/**/b", matches: false, "/a1/2/3/b")
                    checkPattern("/a/**/b", matches: false, "/a/1/2/3b")
                    checkPattern("/**x**",  matches: true,  "/how/many/tests/exactly/do/we/need")
                    checkPattern("/**x**",  matches: false, "/just/a/health/handful")
                    checkPattern("/**/*",   matches: true,  "/a/b")
                    checkPattern("/**/*",   matches: true,  "/ab")
                    }

                it("ignores query strings in the matched URL")
                    {
                    checkPattern("/*/b",  matches: true, "/a/b", params: ["foo": "bar"])
                    checkPattern("/**/b", matches: true, "/a/b", params: ["foo": "bar"])
                    }

                it("handles service with no baseURL")
                    {
                    func checkBareServicePattern(pattern: String, matches: Bool, _ url: String)
                        { checkPattern(pattern, matches: matches, url, absolute: true, service: Service()) }

                    checkBareServicePattern("/foo", matches: true,  "/foo")
                    checkBareServicePattern("/foo", matches: false, "foo")
                    checkBareServicePattern("foo",  matches: false, "/foo")
                    checkBareServicePattern("foo",  matches: true,  "foo")

                    checkBareServicePattern("/foo", matches: false, "http://bar.baz/foo")
                    checkBareServicePattern("http://bar.baz/*", matches: true, "http://bar.baz/foo")
                    }
                }

            it("changes when service config added")
                {
                expect(resource0().config.expirationTime).to(equal(30))
                service().configure { $0.config.expirationTime = 17 }
                expect(resource0().config.expirationTime).to(equal(17))
                service().configure("*oo") { $0.config.expirationTime = 16 }
                expect(resource0().config.expirationTime).to(equal(16))
                }

            it("changes when invalidateConfiguration() called")
                {
                var x: NSTimeInterval = 3
                service().configure { $0.config.expirationTime = x }
                expect(resource0().config.expirationTime).to(equal(3))
                x = 4
                expect(resource0().config.expirationTime).to(equal(3))
                service().invalidateConfiguration()
                expect(resource0().config.expirationTime).to(equal(4))
                }
            }

        describe("wipeResources")
            {
            beforeEach
                {
                resource0().overrideLocalData(Entity(content: "foo content", contentType: "text/plain"))
                resource1().overrideLocalData(Entity(content: "bar content", contentType: "text/plain"))
                }

            it("wipes all resources by default")
                {
                service().wipeResources()
                expect(resource0().latestData).to(beNil())
                expect(resource1().latestData).to(beNil())
                }

            it("can wipe a specific resource")
                {
                service().wipeResources(resource0())
                expect(resource0().latestData).to(beNil())
                expect(resource1().latestData).notTo(beNil())
                }

            it("wipes only resources matching a pattern")
                {
                service().wipeResources("/*o*")
                expect(resource0().latestData).to(beNil())
                expect(resource1().latestData).notTo(beNil())
                }

            it("wipes only resources matched by predicate")
                {
                service().wipeResources() { $0 === resource1() }
                expect(resource0().latestData).notTo(beNil())
                expect(resource1().latestData).to(beNil())
                }
            }
        }
    }


// MARK: - Custom matchers

func expandToBaseURL(expectedURL: String) -> MatcherFunc<String>
    {
    return MatcherFunc
        {
        actual, failureMessage in

        let baseURL = try! actual.evaluate() ?? "",
            service = Service(baseURL: baseURL),
            actualURL = service.baseURL?.absoluteString
        failureMessage.stringValue =
            "expected baseURL \(baseURL.debugDescription)"
            + " to expand to \(expectedURL.debugDescription),"
            + " but got \(actualURL.debugDescription)"
        return actualURL == expectedURL
        }
    }

func expandToResourceURL(expectedURL: String) -> MatcherFunc<(String,String)>
    {
    return MatcherFunc
        {
        inputs, failureMessage in

        let (baseURL, resourcePath) = try! inputs.evaluate()!,
            service = Service(baseURL: baseURL),
            resource = service.resource(resourcePath),
            actualURL = resource.url.absoluteString
        failureMessage.stringValue =
            "expected baseURL \(baseURL.debugDescription)"
            + " and resource path \(resourcePath.debugDescription)"
            + " to expand to \(expectedURL.debugDescription),"
            + " but got \(actualURL.debugDescription)"
        return actualURL == expectedURL
        }
    }

/// Checks resourcePath with and without a leading slash.
///
func checkPathExpansion(baseURL: String, path resourcePath: String, expect expectedExpansion: String)
    {
    for resourcePathVariant in [resourcePath, "/" + resourcePath]
        {
        expect((baseURL, resourcePathVariant))
            .to(expandToResourceURL(expectedExpansion))
        }
    }

func expectInvalidResource(resource: Resource)
    {
    awaitFailure(resource.load())
    }
