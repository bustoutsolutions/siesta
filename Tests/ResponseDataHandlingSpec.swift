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
            stubRequest(resource, "GET").andReturn(200)
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
                expect(resource().text).to(equal("Ã½"))
                }

            it("handles UTF-8")
                {
                stubText("ý", contentType: "text/plain; charset=utf-8")
                expect(resource().text).to(equal("ý"))
                }

            // An Apple bug breaks this spec on iOS 8 _and_ on 32-bit devices (radar 21891847)
            if #available(iOS 9.0, *), sizeof(Int) == sizeof(Int64)
                {
                it("handles more unusual charsets")
                    {
                    stubText("ý", contentType: "text/plain; charset=EUC-JP")
                    expect(resource().text).to(equal("箪"))  // bamboo rice basket
                    }
                }

            it("treats an unknown charset as an errors")
                {
                stubRequest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", "text/plain; charset=oodlefratz")
                    .withBody("abc")
                awaitFailure(resource().load())

                let cause = resource().latestError?.cause as? Error.Cause.InvalidTextEncoding
                expect(cause?.encodingName).to(equal("oodlefratz"))
                }

            it("treats illegal byte sequence for encoding as an error")
                {
                stubRequest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", "text/plain; charset=utf-8")
                    .withBody(NSData(bytes: [0xD8] as [UInt8], length: 1))
                awaitFailure(resource().load())

                let cause = resource().latestError?.cause as? Error.Cause.UndecodableText
                expect(cause?.encodingName).to(equal("utf-8"))
                }

            it("bypasses response if another transformer already made it a string")
                {
                service().configure
                    { $0.config.responseTransformers.add(TestTransformer(), first: true) }
                stubText("blah blah", contentType: "text/plain")
                expect(resource().text).to(equal("<non-string> processed"))
                }

            it("transforms error responses")
                {
                stubRequest(resource, "GET").andReturn(500)
                    .withHeader("Content-Type", "text/plain; charset=UTF-16")
                    .withBody(NSData(bytes: [0xD8, 0x3D, 0xDC, 0xA3] as [UInt8], length: 4))
                awaitFailure(resource().load())
                expect(resource().latestError?.text).to(equal("💣"))
                }

            it("does not parse everything as text")
                {
                stubText(contentType: "application/monkey")
                expect(resource().latestData).notTo(beNil())
                expect(resource().latestData?.content as? String).to(beNil())
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
                    stubRequest(resource, "GET").andReturn(404)
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
                stubRequest(resource, "GET").andReturn(200)
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
                stubRequest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", "application/json")
                    .withBody("{\"foo\":•√£™˚")
                awaitFailure(resource().load())

                expect(resource().latestData).to(beNil())
                expect(resource().latestError).notTo(beNil())
                expect(resource().latestError?.userMessage).to(equal("Cannot parse server response"))
                let nsError = resource().latestError?.cause as? NSError
                expect(nsError).notTo(beNil())
                expect(nsError?.domain).to(equal("NSCocoaErrorDomain"))
                expect(nsError?.code).to(equal(3840))
                }

            it("treats top-level JSON that is not a dictionary or array as an error")
                {
                for atom in ["17", "\"foo\"", "null"]
                    {
                    stubRequest(resource, "GET").andReturn(200)
                        .withHeader("Content-Type", "application/json")
                        .withBody(atom)
                    awaitFailure(resource().load())

                    expect(resource().latestError?.cause is Error.Cause.JSONResponseIsNotDictionaryOrArray).to(beTrue())
                    }
                }

            it("transforms error responses")
                {
                stubRequest(resource, "GET").andReturn(500)
                    .withHeader("Content-Type", "application/json")
                    .withBody("{ \"error\": \"pigeon drove bus\" }")
                awaitFailure(resource().load())
                expect(resource().latestError?.jsonDict as? [String:String])
                    .to(equal(["error": "pigeon drove bus"]))
                }

            it("preserves root error if error response is unparsable")
                {
                stubRequest(resource, "GET").andReturn(500)
                    .withHeader("Content-Type", "application/json")
                    .withBody("{ malformed JSON[[{{#$!@")
                awaitFailure(resource().load())
                expect(resource().latestError?.userMessage).to(equal("Internal server error"))
                expect(resource().latestError?.entity?.content as? NSData).notTo(beNil())
                }

            describe("via .jsonDict convenience")
                {
                it("gives JSON data")
                    {
                    stubJson()
                    expect(resource().jsonDict).to(equal(jsonVal))
                    }

                it("gives empty dict for non-JSON response")
                    {
                    stubJson(contentType: "text/plain")
                    expect(resource().jsonDict).to(equal(NSDictionary()))
                    }

                it("gives empty dict on error")
                    {
                    stubRequest(resource, "GET").andReturn(500)
                    expect(resource().jsonDict).to(equal(NSDictionary()))
                    }
                }

            describe("via .jsonArray convenience")
                {
                it("gives JSON data")
                    {
                    stubRequest(resource, "GET").andReturn(200)
                        .withHeader("Content-Type", "application/json")
                        .withBody("[1,\"two\"]")
                    awaitNewData(resource().load())
                    expect(resource().jsonArray).to(equal([1,"two"] as NSArray))
                    }

                it("gives empty dict for non-dict response")
                    {
                    stubJson()
                    expect(resource().jsonArray).to(equal(NSArray()))
                    }
                }
            }

        describe("image handling")
            {
            it("parses images")
                {
                stubRequest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", "image/gif")
                    .withBody(NSData(
                        base64EncodedString: "R0lGODlhAQABAIAAAP///wAAACwAAAAAAQABAAACAkQBADs=",
                        options: []))
                awaitNewData(resource().load())
                let image: UIImage? = resource().latestData?.content as? UIImage
                expect(image).notTo(beNil())
                expect(image?.size).to(equal(CGSize(width: 1, height: 1)))
                }

            it("gives an error for unparsable images")
                {
                stubRequest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", "image/gif")
                    .withBody("Ceci n’est pas une image")
                awaitFailure(resource().load())

                expect(resource().latestError?.cause is Error.Cause.UnparsableImage).to(beTrue())
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
                    stubRequest(resource, "GET").andReturn(200)
                        .withHeader("Content-Type", contentType)
                        .withBody("]]glarble}{blargble[[")
                    awaitNewData(resource().load())

                    expect(resource().latestData?.content is NSData).to(beTrue())
                    }
                }
            }

        describe("custom transformer")
            {
            context("using ResponseTransformer protocol")
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
                    stubRequest(resource, "GET").andReturn(401)
                    awaitFailure(resource().load())
                    expect(resource().latestError?.userMessage).to(equal("Unauthorized processed"))
                    expect(transformer().callCount).to(equal(1))
                    }

                it("does not reprocess existing data on 304")
                    {
                    stubText("ahoy")

                    LSNocilla.sharedInstance().clearStubs()
                    stubRequest(resource, "GET").andReturn(304)
                    awaitNotModified(resource().load())

                    expect(resource().latestData?.content as? String).to(equal("ahoy processed"))
                    expect(transformer().callCount).to(equal(1))
                    }
                }

            context("using closure")
                {
                beforeEach
                    {
                    service().configureTransformer("**")
                        { TestModel(name: $0.content) }
                    }

                it("can transform data")
                    {
                    stubText("Fred")
                    let model = resource().latestData?.content as? TestModel
                    expect(model?.name).to(equal("Fred"))
                    }

                it("leaves errors untouched")
                    {
                    stubRequest(resource, "GET").andReturn(500)
                        .withHeader("Content-Type", "text/plain")
                        .withBody("I am not a model")
                    awaitFailure(resource().load())
                    expect(resource().latestData?.content).to(beNil())
                    expect(resource().latestError?.text).to(equal("I am not a model"))
                    }

                it("infers input type and treats wrong type as an error")
                    {
                    stubRequest(resource, "GET")
                        .andReturn(200)
                        .withHeader("Content-Type", "application/json")
                        .withBody("{}")
                    awaitFailure(resource().load())
                    expect(resource().latestData?.content is TestModel).to(beFalse())

                    expect(resource().latestError?.cause is Error.Cause.WrongTypeInTranformerPipeline).to(beTrue())
                    }

                it("infers output type and skips content if already transformed")
                    {
                    service().configureTransformer("**")
                        {
                        (content: String, entity: Entity) in
                        return TestModel(name: "should not be called")
                        }
                    stubText("Fred")
                    let model = resource().latestData?.content as? TestModel
                    expect(model?.name).to(equal("Fred"))
                    }

                it("can throw a custom error")
                    {
                    service().configure
                        { $0.config.responseTransformers.clear() }
                    service().configureTransformer("**")
                        {
                        (_: NSData, _) -> String in
                        throw CustomError()
                        }

                    stubRequest(resource, "GET").andReturn(200).withBody("YUP")
                    awaitFailure(resource().load())
                    expect(resource().latestError?.cause is CustomError).to(beTrue())
                    }

                it("can throw a Siesta.Error")
                    {
                    service().configure
                        { $0.config.responseTransformers.clear() }
                    service().configureTransformer("**")
                        {
                        (_: NSData, _) -> String in
                        throw Error(userMessage: "Everything is broken", cause: CustomError())
                        }

                    stubRequest(resource, "GET").andReturn(200).withBody("YUP")
                    awaitFailure(resource().load())
                    expect(resource().latestError?.userMessage).to(equal("Everything is broken"))
                    expect(resource().latestError?.cause is CustomError).to(beTrue())
                    }
                }
            }

        describe("contentAsType()")
            {
            it("returns content if present")
                {
                stubText()
                awaitNewData(resource().load())
                let content = resource().contentAsType(ifNone: "default value")
                expect(content).to(equal("zwobble"))
                }

            it("returns default if no content")
                {
                let content = resource().contentAsType(ifNone: "default value")
                expect(content).to(equal("default value"))
                }

            it("returns default if content present but wrong type")
                {
                stubText(contentType: "foo/bar")  // suppresses text parsing
                awaitNewData(resource().load())
                let content = resource().contentAsType(ifNone: "default value")
                expect(content).to(equal("default value"))
                }

            it("can handle optional defaults")
                {
                let some: String? = "ahoy",
                    none: String? = nil
                expect(resource().contentAsType(ifNone: some)).to(equal("ahoy"))
                expect(resource().contentAsType(ifNone: none)).to(beNil())
                }

            it("does not evaluate default unless needed")
                {
                var suddenDeathCalled = false
                func suddenDeath() -> String
                    {
                    suddenDeathCalled = true
                    return "DOOOOM!!!"
                    }

                stubText()
                awaitNewData(resource().load())
                expect(resource().contentAsType(ifNone: suddenDeath())).notTo(beNil())
                expect(suddenDeathCalled).to(beFalse())
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

private struct TestModel
    {
    let name: String

    init(name: String)
        { self.name = name }
    }

private struct CustomError: ErrorType { }
