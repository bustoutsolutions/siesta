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

class ResponseDataHandlingSpec: ResourceSpecBase
    {
    override func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        {
        func stubText(string: String? = "zwobble", contentType: String = "text/plain")
            {
            stubReqest(resource, "GET").andReturn(200)
                .withHeader("Content-Type", contentType)
                .withBody(string)
            awaitNewData(resource().load())
            }
        
        describe("plain text handling")
            {
            for textType in ["text/plain", "text/foo"]
                {
                it("parses \(textType) as text")
                    {
                    stubText(contentType: textType)
                    expect(resource().latestData?.content as? String).to(equal("zwobble"))
                    }
                }

            it("defaults to ISO-8859-1")
                {
                stubText("ý", contentType: "text/plain")
                expect(resource().textContent).to(equal("Ã½"))
                }

            it("handles UTF-8")
                {
                stubText("ý", contentType: "text/plain; charset=utf-8")
                expect(resource().textContent).to(equal("ý"))
                }
            
            it("handles more unusual charsets")
                {
                stubText("ý", contentType: "text/plain; charset=EUC-JP")
                expect(resource().textContent).to(equal("箪"))  // bamboo rice basket
                // Note: assertion above fails on iPhone 4S and 5 simulators (apparently an Apple bug?)
                }
            
            it("treats an unknown charset as an errors")
                {
                stubReqest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", "text/plain; charset=oodlefratz")
                    .withBody("abc")
                awaitFailure(resource().load())
                }
            
            it("treats illegal byte sequence for encoding as an error")
                {
                stubReqest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", "text/plain; charset=utf-8")
                    .withBody(NSData(bytes: [0xD8] as [UInt8], length: 1))
                awaitFailure(resource().load())
                }
            
            it("bypasses response if another transformer already made it a string")
                {
                service().configure
                    { $0.config.responseTransformers.add(TestTransformer(), first: true) }
                stubText("blah blah", contentType: "text/plain")
                expect(resource().textContent).to(equal("<non-string> processed"))
                }

            it("transforms error responses")
                {
                stubReqest(resource, "GET").andReturn(500)
                    .withHeader("Content-Type", "text/plain; charset=UTF-16")
                    .withBody(NSData(bytes: [0xD8, 0x3D, 0xDC, 0xA3] as [UInt8], length: 4))
                awaitFailure(resource().load())
                expect(resource().latestError?.textContent).to(equal("💣"))
                }

            it("does not parse everything as text")
                {
                stubText(contentType: "application/monkey")
                expect(resource().latestData).notTo(beNil())
                expect(resource().latestData?.content as? String).to(beNil())
                }
            
            describe("via .textContent convenience")
                {
                it("gives a string")
                    {
                    stubText()
                    expect(resource().textContent).to(equal("zwobble"))
                    }

                it("gives empty string for non-text response")
                    {
                    stubText(contentType: "application/octet-stream")
                    expect(resource().textContent).to(equal(""))
                    }

                it("gives empty string on error")
                    {
                    stubReqest(resource, "GET").andReturn(404)
                    expect(resource().textContent).to(equal(""))
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
                awaitNewData(resource().load())
                }
            
            for jsonType in ["application/json", "application/foo+json", "foo/json"]
                {
                it("parses \(jsonType) as JSON")
                    {
                    stubJson(contentType: jsonType)
                    expect(resource().latestData?.content as? NSDictionary).to(equal(jsonVal))
                    }
                }

            it("does not parse everything as JSON")
                {
                stubJson(contentType: "text/plain")
                expect(resource().latestData).notTo(beNil())
                expect(resource().latestData?.content as? NSDictionary).to(beNil())
                }
            
            it("reports JSON parse errors")
                {
                stubReqest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", "application/json")
                    .withBody("{\"foo\":•√£™˚")
                awaitFailure(resource().load())
                
                expect(resource().latestData).to(beNil())
                expect(resource().latestError).notTo(beNil())
                expect(resource().latestError?.userMessage).to(equal("Cannot parse JSON"))
                expect(resource().latestError?.nsError?.domain).to(equal("NSCocoaErrorDomain"))
                expect(resource().latestError?.nsError?.code).to(equal(3840))
                }
            
            it("transforms error responses")
                {
                stubReqest(resource, "GET").andReturn(500)
                    .withHeader("Content-Type", "application/json")
                    .withBody("{ \"error\": \"pigeon drove bus\" }")
                awaitFailure(resource().load())
                expect(resource().latestError?.dictContent as? [String:String])
                    .to(equal(["error": "pigeon drove bus"]))
                }

            it("preserves root error if error response is unparsable")
                {
                stubReqest(resource, "GET").andReturn(500)
                    .withHeader("Content-Type", "application/json")
                    .withBody("{ malformed JSON[[{{#$!@")
                awaitFailure(resource().load())
                expect(resource().latestError?.userMessage).to(equal("Internal server error"))
                expect(resource().latestError?.entity?.content as? NSData).notTo(beNil())
                }

            describe("via .dictContent convenience")
                {
                it("gives JSON data")
                    {
                    stubJson()
                    expect(resource().dictContent).to(equal(jsonVal))
                    }

                it("gives empty dict for non-JSON response")
                    {
                    stubJson(contentType: "text/plain")
                    expect(resource().dictContent).to(equal(NSDictionary()))
                    }

                it("gives empty dict on error")
                    {
                    stubReqest(resource, "GET").andReturn(500)
                    expect(resource().dictContent).to(equal(NSDictionary()))
                    }
                }
            
            describe("via .arrayContent convenience")
                {
                it("gives JSON data")
                    {
                    stubReqest(resource, "GET").andReturn(200)
                        .withHeader("Content-Type", "application/json")
                        .withBody("[1,\"two\"]")
                    awaitNewData(resource().load())
                    expect(resource().arrayContent).to(equal([1,"two"] as NSArray))
                    }

                it("gives empty dict for non-dict response")
                    {
                    stubJson()
                    expect(resource().arrayContent).to(equal(NSArray()))
                    }
                }
            }

        describe("with standard parsing disabled in configuration")
            {
            beforeEach
                {
                service().configure { $0.config.responseTransformers.clear() }
                }
            
            for contentType in ["text/plain", "application/json"]
                {
                it("does not parse \(contentType)")
                    {
                    stubReqest(resource, "GET").andReturn(200)
                        .withHeader("Content-Type", contentType)
                        .withBody("]]glarble}{blargble[[")
                    awaitNewData(resource().load())
                    
                    expect(resource().latestData?.content is NSData).to(beTrue())
                    }
                }
            }
        
        describe("custom transformer")
            {
            let transformer = specVar { TestTransformer() }
            
            beforeEach
                {
                service().configure
                    { $0.config.responseTransformers.add(transformer()) }
                }
            
            it("can transform data")
                {
                stubText("greetings")
                expect(resource().latestData?.content as? String).to(equal("greetings processed"))
                expect(transformer().callCount).to(equal(1))
                }
            
            it("can transform errors")
                {
                stubReqest(resource, "GET").andReturn(401)
                awaitFailure(resource().load())
                expect(resource().latestError?.userMessage).to(equal("Unauthorized processed"))
                expect(transformer().callCount).to(equal(1))
                }
            
            it("does not reprocess existing data on 304")
                {
                stubText("ahoy")

                LSNocilla.sharedInstance().clearStubs()
                stubReqest(resource, "GET").andReturn(304)
                awaitNotModified(resource().load())
                
                expect(resource().latestData?.content as? String).to(equal("ahoy processed"))
                expect(transformer().callCount).to(equal(1))
                }
            }
        }
    }

private class TestTransformer: ResponseTransformer
    {
    var callCount = 0
    
    private func process(response: Response) -> Response
        {
        callCount++
        switch response
            {
            case .Success(var entity):
                entity.content = (entity.content as? String ?? "<non-string>") + " processed"
                return .Success(entity)
            
            case .Failure(var error):
                error.userMessage += " processed"
                return .Failure(error)
            }
        }
    }
