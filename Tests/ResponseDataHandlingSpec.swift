//
//  ResponseDataHandlingSpec.swift
//  Siesta
//
//  Created by Paul on 2015/7/8.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble
import Nocilla

class ResponseDataHandlingSpec: ResourceSpecBase
    {
    override func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        {
        func stubText(
                string: String? = "zwobble",
                method: String = "GET",
                contentType: String = "text/plain",
                expectSuccess: Bool = true)
            {
            stubRequest(resource, method).andReturn(200)
                .withHeader("Content-Type", contentType)
                .withBody(string)
            let awaitRequest = expectSuccess ? awaitNewData : awaitFailure
            awaitRequest(resource().load(), alreadyCompleted: false)
            }

        describe("plain text handling")
            {
            for textType in ["text/plain", "text/foo"]
                {
                it("parses \(textType) as text")
                    {
                    stubText(contentType: textType)
                    expect(resource().typedContent()) == "zwobble"
                    }
                }

            it("defaults to ISO-8859-1")
                {
                stubText("ý", contentType: "text/plain")
                expect(resource().text) == "Ã½"
                }

            it("handles UTF-8")
                {
                stubText("ý", contentType: "text/plain; charset=utf-8")
                expect(resource().text) == "ý"
                }

            // An Apple bug breaks this spec on iOS 8 _and_ on 32-bit devices (radar 21891847)
            if #available(iOS 9.0, *), sizeof(Int) == sizeof(Int64)
                {
                it("handles more unusual charsets")
                    {
                    stubText("ý", contentType: "text/plain; charset=EUC-JP")
                    expect(resource().text) == "箪"  // bamboo rice basket
                    }
                }

            it("treats an unknown charset as an errors")
                {
                stubText("abc", contentType: "text/plain; charset=oodlefratz", expectSuccess: false)

                let cause = resource().latestError?.cause as? Error.Cause.InvalidTextEncoding
                expect(cause?.encodingName) == "oodlefratz"
                }

            it("treats illegal byte sequence for encoding as an error")
                {
                stubRequest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", "text/plain; charset=utf-8")
                    .withBody(NSData(bytes: [0xD8] as [UInt8], length: 1))
                awaitFailure(resource().load())

                let cause = resource().latestError?.cause as? Error.Cause.UndecodableText
                expect(cause?.encodingName) == "utf-8"
                }

            it("bypasses response if another transformer already made it a string")
                {
                service().configure
                    { $0.config.pipeline[.decoding].add(TestTransformer()) }
                stubText("blah blah", contentType: "text/plain")
                expect(resource().text) == "<non-string> processed"
                }

            it("transforms error responses")
                {
                stubRequest(resource, "GET").andReturn(500)
                    .withHeader("Content-Type", "text/plain; charset=UTF-16")
                    .withBody(NSData(bytes: [0xD8, 0x3D, 0xDC, 0xA3] as [UInt8], length: 4))
                awaitFailure(resource().load())
                expect(resource().latestError?.text) == "💣"
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
                    expect(resource().text) == "zwobble"
                    }

                it("gives empty string for non-text response")
                    {
                    stubText(contentType: "application/octet-stream")
                    expect(resource().text) == ""
                    }

                it("gives empty string on error")
                    {
                    stubRequest(resource, "GET").andReturn(404)
                    expect(resource().text) == ""
                    }
                }
            }

        describe("JSON handling")
            {
            let jsonStr = "{\"foo\":[\"bar\",42]}"
            let jsonVal = ["foo": ["bar", 42]] as NSDictionary

            func stubJson(contentType contentType: String = "application/json", expectSuccess: Bool = true)
                {
                stubText(jsonStr, contentType: contentType, expectSuccess: expectSuccess)
                }

            for jsonType in ["application/json", "application/foo+json", "foo/json"]
                {
                it("parses \(jsonType) as JSON")
                    {
                    stubJson(contentType: jsonType)
                    expect(resource().typedContent()) == jsonVal
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
                stubText("{\"foo\":•√£™˚", contentType: "application/json", expectSuccess: false)

                expect(resource().latestData).to(beNil())
                expect(resource().latestError).notTo(beNil())
                expect(resource().latestError?.userMessage) == "Cannot parse server response"
                let nsError = resource().latestError?.cause as? NSError
                expect(nsError).notTo(beNil())
                expect(nsError?.domain) == "NSCocoaErrorDomain"
                expect(nsError?.code) == 3840
                }

            it("treats top-level JSON that is not a dictionary or array as an error")
                {
                for atom in ["17", "\"foo\"", "null"]
                    {
                    stubRequest(resource, "GET").andReturn(200)
                        .withHeader("Content-Type", "application/json")
                        .withBody(atom)
                    awaitFailure(resource().load())

                    expect(resource().latestError?.cause is Error.Cause.JSONResponseIsNotDictionaryOrArray) == true
                    }
                }

            it("transforms error responses")
                {
                stubRequest(resource, "GET").andReturn(500)
                    .withHeader("Content-Type", "application/json")
                    .withBody("{ \"error\": \"pigeon drove bus\" }")
                awaitFailure(resource().load())
                expect(resource().latestError?.jsonDict as? [String:String])
                     == ["error": "pigeon drove bus"]
                }

            it("preserves root error if error response is unparsable")
                {
                stubRequest(resource, "GET").andReturn(500)
                    .withHeader("Content-Type", "application/json")
                    .withBody("{ malformed JSON[[{{#$!@")
                awaitFailure(resource().load())
                expect(resource().latestError?.userMessage) == "Internal server error"
                expect(resource().latestError?.entity?.content as? NSData).notTo(beNil())
                }

            describe("via .jsonDict convenience")
                {
                it("gives JSON data")
                    {
                    stubJson()
                    expect(resource().jsonDict) == jsonVal
                    }

                it("gives empty dict for non-JSON response")
                    {
                    stubJson(contentType: "text/plain")
                    expect(resource().jsonDict) == NSDictionary()
                    }

                it("gives empty dict on error")
                    {
                    stubRequest(resource, "GET").andReturn(500)
                    expect(resource().jsonDict) == NSDictionary()
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
                    expect(resource().jsonArray) == [1,"two"] as NSArray
                    }

                it("gives empty dict for non-dict response")
                    {
                    stubJson()
                    expect(resource().jsonArray) == NSArray()
                    }
                }

            it("can log JSON-like container with non-JSON contents")
                {
                let notValidJSONObject: NSArray = [NSObject()]
                service().configureTransformer("**")
                    { (_: Any, _) in notValidJSONObject }

                stubJson()
                expect(resource().typedContent()) === notValidJSONObject
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
                let image: Image? = resource().typedContent()
                expect(image).notTo(beNil())
                expect(image?.size) == CGSize(width: 1, height: 1)
                }

            it("gives an error for unparsable images")
                {
                stubRequest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", "image/gif")
                    .withBody("Ceci n’est pas une image")
                awaitFailure(resource().load())

                expect(resource().latestError?.cause is Error.Cause.UnparsableImage) == true
                }
            }

        describe("with standard parsing disabled in configuration")
            {
            beforeEach
                {
                service().configure { $0.config.pipeline.clear() }
                }

            for contentType in ["text/plain", "application/json"]
                {
                it("does not parse \(contentType)")
                    {
                    stubRequest(resource, "GET").andReturn(200)
                        .withHeader("Content-Type", contentType)
                        .withBody("]]glarble}{blargble[[")
                    awaitNewData(resource().load())

                    expect(resource().latestData?.content is NSData) == true
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
                        { $0.config.pipeline[.parsing].add(transformer()) }
                    }

                it("can transform data")
                    {
                    stubText("greetings")
                    expect(resource().typedContent()) == "greetings processed"
                    expect(transformer().callCount) == 1
                    }

                it("can transform errors")
                    {
                    stubRequest(resource, "GET").andReturn(401)
                    awaitFailure(resource().load())
                    expect(resource().latestError?.userMessage) == "Unauthorized processed"
                    expect(transformer().callCount) == 1
                    }

                it("does not reprocess existing data on 304")
                    {
                    stubText("ahoy")

                    LSNocilla.sharedInstance().clearStubs()
                    stubRequest(resource, "GET").andReturn(304)
                    awaitNotModified(resource().load())

                    expect(resource().typedContent()) == "ahoy processed"
                    expect(transformer().callCount) == 1
                    }
                }

            context("using closure")
                {
                func configureModelTransformer()
                    {
                    service().configureTransformer("**")
                        { TestModel(name: $0.content) }
                    }

                it("can transform data")
                    {
                    configureModelTransformer()
                    stubText("Fred")
                    let model: TestModel? = resource().typedContent()
                    expect(model?.name) == "Fred"
                    }

                it("leaves errors untouched")
                    {
                    configureModelTransformer()
                    stubRequest(resource, "GET").andReturn(500)
                        .withHeader("Content-Type", "text/plain")
                        .withBody("I am not a model")
                    awaitFailure(resource().load())
                    expect(resource().latestData).to(beNil())
                    expect(resource().latestError?.text) == "I am not a model"
                    }

                it("infers input type and treats wrong type as an error")
                    {
                    configureModelTransformer()
                    stubText("{}", contentType: "application/json", expectSuccess: false)
                    expect(resource().latestData).to(beNil())

                    expect(resource().latestError?.cause is Error.Cause.WrongTypeInTranformerPipeline) == true
                    }

                it("infers output type and skips content if already transformed")
                    {
                    configureModelTransformer()
                    service().configureTransformer("**", atStage: .cleanup)
                        {
                        (content: String, entity: Entity) in
                        return TestModel(name: "should not be called")
                        }
                    stubText("Fred")
                    let model: TestModel? = resource().typedContent()
                    expect(model?.name) == "Fred"
                    }

                it("can throw a custom error")
                    {
                    service().configureTransformer("**")
                        {
                        (_: String, _) -> NSDate in
                        throw CustomError()
                        }

                    stubText("YUP", expectSuccess: false)
                    expect(resource().latestError?.cause is CustomError) == true
                    }

                it("can throw a Siesta.Error")
                    {
                    service().configureTransformer("**")
                        {
                        (text: String, _) -> NSDate in
                        throw Error(userMessage: "\(text) is broken", cause: CustomError())
                        }

                    stubText("Everything", expectSuccess: false)
                    expect(resource().latestError?.userMessage) == "Everything is broken"
                    expect(resource().latestError?.cause is CustomError) == true
                    }

                it("replaces previously configured model transformers")
                    {
                    configureModelTransformer()
                    service().configureTransformer("**")
                        { TestModel(name: "extra " + $0.content) }

                    stubText("wasabi")
                    let model: TestModel? = resource().typedContent()
                    expect(model?.name) == "extra wasabi"
                    }

                func stubTextRequest(string: String, method: RequestMethod) -> Entity
                    {
                    stubRequest(resource, method.rawValue).andReturn(200)
                        .withHeader("Content-Type", "text/plain")
                        .withBody(string)

                    var result: Entity? = nil
                    let req = resource().request(method)
                    req.onSuccess { result = $0 }
                    awaitNewData(req)

                    return result!
                    }

                it("can be limited to specific HTTP request methods")
                    {
                    service().configureTransformer("**", requestMethods: [.PUT, .POST])
                        { TestModel(name: $0.content) }

                    let getResult: String? = stubTextRequest("got it", method: .GET).typedContent()
                    expect(getResult) == "got it"

                    let postResult: TestModel? = stubTextRequest("posted it", method: .POST).typedContent()
                    expect(postResult?.name) == "posted it"
                    }

                context("that returns an optional")
                    {
                    beforeEach
                        {
                        service().configureTransformer("**")
                            { TestModel(anythingButOrange: $0.content) }
                        }

                    it("can return nil to signal failure")
                        {
                        stubText("Orange", expectSuccess: false)
                        awaitFailure(resource().load())
                        expect(resource().latestError?.cause is Error.Cause.TransformerReturnedNil) == true
                        }

                    it("can return a value to signal success")
                        {
                        stubText("Green")
                        awaitNewData(resource().load())
                        let model: TestModel? = resource().typedContent()
                        expect(model?.name) == "Green"
                        }
                    }
                }
            }

        describe("typedContent()")
            {
            it("returns content if present")
                {
                stubText()
                awaitNewData(resource().load())
                let content = resource().typedContent(ifNone: "default value")
                expect(content) == "zwobble"
                }

            it("returns default if no content")
                {
                let content = resource().typedContent(ifNone: "default value")
                expect(content) == "default value"
                }

            it("returns default if content present but wrong type")
                {
                stubText(contentType: "foo/bar")  // suppresses text parsing
                awaitNewData(resource().load())
                let content = resource().typedContent(ifNone: "default value")
                expect(content) == "default value"
                }

            it("can handle optional defaults")
                {
                let some: String? = "ahoy",
                    none: String? = nil
                expect(resource().typedContent(ifNone: some)) == "ahoy"
                expect(resource().typedContent(ifNone: none)).to(beNil())
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
                expect(resource().typedContent(ifNone: suddenDeath())).notTo(beNil())
                expect(suddenDeathCalled) == false
                }
            }
        }
    }

private class TestTransformer: ResponseTransformer
    {
    var callCount = 0

    private func process(response: Response) -> Response
        {
        callCount += 1
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

    init?(anythingButOrange name: String)
        {
        guard name != "Orange" else
            { return nil }
        self.init(name: name)
        }
    }

private struct CustomError: ErrorType { }
