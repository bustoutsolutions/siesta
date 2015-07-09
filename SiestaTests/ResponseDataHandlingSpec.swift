//
//  ResponseDataHandlingSpec.swift
//  Siesta
//
//  Created by Paul on 2015/7/8.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble
import Nocilla
import Alamofire

class ResponseDataHandlingSpec: ResourceSpecBase
    {
    override func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        {
        describe("plain text handling")
            {
            func stubText(string: String? = "zwobble", contentType: String = "text/plain")
                {
                stubReqest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", contentType)
                    .withBody(string)
                awaitResponse(resource().load())
                }
            
            for textType in ["text/plain", "text/foo"]
                {
                it("parses \(textType) as text")
                    {
                    stubText(contentType: textType)
                    expect(resource().data as? String).to(equal("zwobble"))
                    }
                }

            it("defaults to ISO-8859-1")
                {
                stubText("ý", contentType: "text/plain")
                expect(resource().text).to(equal("Ã½"))
                }

            it("handles UTF-8")
                {
                stubText("ý", contentType: "text/plain; charset=utf-8")
                expect(resource().text).to(equal("ý"))
                }
            
            it("handles more unusual charsets")
                {
                stubText("ý", contentType: "text/plain; charset=EUC-JP")
                expect(resource().text).to(equal("箪"))  // bamboo rice basket
                }

            it("does not parse everything as text")
                {
                stubText(contentType: "application/monkey")
                expect(resource().latestData).notTo(beNil())
                expect(resource().data as? String).to(beNil())
                }
            
            describe("via .text convenience")
                {
                it("gives a string")
                    {
                    stubText()
                    expect(resource().text).to(equal("zwobble"))
                    }

                it("gives empty string for non-text response")
                    {
                    stubText(contentType: "application/octet-stream")
                    expect(resource().text).to(equal(""))
                    }

                it("gives empty string on error")
                    {
                    stubReqest(resource, "GET").andReturn(404)
                    expect(resource().text).to(equal(""))
                    }
                }
            }
        
        describe("JSON handling")
            {
            let jsonStr = "{\"foo\":[\"bar\",42]}"
            let jsonVal = ["foo": ["bar", 42]] as NSDictionary
            
            func stubJson(contentType contentType: String = "application/json")
                {
                stubReqest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", contentType)
                    .withBody(jsonStr)
                awaitResponse(resource().load())
                }
            
            for jsonType in ["application/json", "application/foo+json", "foo/json"]
                {
                it("parses \(jsonType) as JSON")
                    {
                    stubJson(contentType: jsonType)
                    expect(resource().data as? NSDictionary).to(equal(jsonVal))
                    }
                }

            it("does not parse everything as JSON")
                {
                stubJson(contentType: "text/plain")
                expect(resource().latestData).notTo(beNil())
                expect(resource().data as? NSDictionary).to(beNil())
                }
            
            it("reports JSON parse errors")
                {
                stubReqest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", "application/json")
                    .withBody("{\"foo\":•√£™˚")
                awaitResponse(resource().load())
                
                expect(resource().latestData).to(beNil())
                expect(resource().latestError).notTo(beNil())
                expect(resource().latestError?.userMessage).to(equal("Cannot parse JSON"))
                expect(resource().latestError?.nsError?.domain).to(equal("NSCocoaErrorDomain"))
                expect(resource().latestError?.nsError?.code).to(equal(3840))
                }
            
            describe("via .json convenience")
                {
                it("gives JSON data")
                    {
                    stubJson()
                    expect(resource().json).to(equal(jsonVal))
                    }

                it("gives empty dict for non-JSON response")
                    {
                    stubJson(contentType: "text/plain")
                    expect(resource().json).to(equal(NSDictionary()))
                    }

                it("gives empty dict on error")
                    {
                    stubReqest(resource, "GET").andReturn(500)
                    expect(resource().json).to(equal(NSDictionary()))
                    }
                }
            }
        }
    }