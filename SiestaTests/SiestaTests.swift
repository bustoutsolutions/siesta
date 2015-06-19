//
//  SiestaTests.swift
//  SiestaTests
//
//  Created by Paul on 2015/6/14.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble

class SiestaTests: QuickSpec
    {
    lazy var serviceWithInvalidBase = Service(baseURL: nil)
    
    override func spec()
        {
        describe("init()")
            {
            func checkBaseURLExpansion(base: String, _ expectedExpansion: String)
                {
                let service = Service(base: base)
                expect(service.baseURL?.absoluteString).to(equal(expectedExpansion))
                }
            
            it("removes the trailing slash from baseURL")
                {
                checkBaseURLExpansion("http://foo.bar/",     "http://foo.bar")
                checkBaseURLExpansion("http://foo.bar/baz/", "http://foo.bar/baz")
                }
                
            it("preserves baseURL query parameters")
                {
                checkBaseURLExpansion("http://foo.bar/baz?you=mysunshine",  "http://foo.bar/baz?you=mysunshine")
                checkBaseURLExpansion("http://foo.bar/baz/?you=mysunshine", "http://foo.bar/baz?you=mysunshine")
                }
            }
        
        describe("resource()")
            {
            // Checks baseURL with and without a trailing slash, and resourcePath with and without a leading slash.
            // Because Service.resource(path:) resolves everything as a subpath of the base URL, these four cases
            // should always give identical results.
            
            func checkPathExpansion(base: String, _ resourcePath: String, _ expectedExpansion: String)
                {
                for baseVariant in [base, base + "/"]
                    {
                    for resourcePathVariant in [resourcePath, "/" + resourcePath]
                        {
                        let service = Service(base: baseVariant)
                        let resource = service.resource(resourcePathVariant)
                        expect(resource.url?.absoluteString)
                            .to(equal(expectedExpansion))
                        }
                    }
                }
            
            it("resolves all paths as subpaths of base URL")
                {
                checkPathExpansion("https://foo.bar",    "baz",      "https://foo.bar/baz")
                checkPathExpansion("https://foo.bar",    "baz/fez",  "https://foo.bar/baz/fez")
                checkPathExpansion("https://foo.bar",    "baz/fez/", "https://foo.bar/baz/fez/")
                checkPathExpansion("https://foo.bar/v1", "baz",      "https://foo.bar/v1/baz")
                checkPathExpansion("https://foo.bar/v1", "baz/fez",  "https://foo.bar/v1/baz/fez")
                }
            }
        }
    }
