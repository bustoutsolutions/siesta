//
//  ResponseDataHandlingSpec.swift
//  Siesta
//
//  Created by Paul on 2015/7/8.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta

import Foundation
import Quick
import Nimble

class ResponseDataHandlingSpec: ResourceSpecBase
    {
    override func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource)
        {
        func stubText(
                _ string: String? = "zwobble",
                contentType: String = "text/plain",
                expectSuccess: Bool = true)
            {
            NetworkStub.add(
                .get, resource,
                returning: HTTPResponse(
                    headers:
                        [
                        "Content-Type": contentType,
                        "X-Custom-Header": "Sprotzle"
                        ],
                    body: string))
            let awaitRequest = expectSuccess ? awaitNewData : awaitFailure
            awaitRequest(resource().load(), .inProgress)
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
            if #available(iOS 9.0, *), MemoryLayout<Int>.size == MemoryLayout<Int64>.size
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

                let cause = resource().latestError?.cause as? RequestError.Cause.InvalidTextEncoding
                expect(cause?.encodingName) == "oodlefratz"
                }

            it("treats illegal byte sequence for encoding as an error")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(
                        headers: ["Content-Type": "text/plain; charset=utf-8"],
                        body: Data([0xD8])))
                awaitFailure(resource().load())

                let cause = resource().latestError?.cause as? RequestError.Cause.UndecodableText
                expect(cause?.encoding) == String.Encoding.utf8
                }

            it("reports an error if another transformer already made it a string")
                {
                service().configure
                    { $0.pipeline[.decoding].add(TestTransformer()) }
                stubText("blah blah", contentType: "text/plain", expectSuccess: false)
                expect(resource().latestError?.cause is RequestError.Cause.WrongInputTypeInTranformerPipeline) == true
                if let wrongTypeError = resource().latestError?.cause as? RequestError.Cause.WrongInputTypeInTranformerPipeline
                    {
                    expect(wrongTypeError.expectedType == Data.self) == true
                    expect(wrongTypeError.actualType == String.self) == true
                    }
                }

            it("transforms error responses")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(
                        status: 500,
                        headers: ["Content-Type": "text/plain; charset=UTF-16"],
                        body: Data([0xD8, 0x3D, 0xDC, 0xA3])))
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
                    NetworkStub.add(.get, resource, status: 404)
                    expect(resource().text) == ""
                    }
                }
            }

        describe("JSON handling")
            {
            let jsonStr = "{\"foo\":[\"bar\",42]}"
            let jsonVal = ["foo": ["bar", 42]]

            func stubJson(contentType: String = "application/json", expectSuccess: Bool = true)
                {
                stubText(jsonStr, contentType: contentType, expectSuccess: expectSuccess)
                }

            for jsonType in ["application/json", "application/foo+json", "foo/json"]
                {
                it("parses \(jsonType) as JSON")
                    {
                    stubJson(contentType: jsonType)
                    expect(resource().typedContent() as NSDictionary?) == jsonVal as NSObject
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
                let nsError = resource().latestError?.cause as NSError?
                expect(nsError).notTo(beNil())
                expect(nsError?.domain) == "NSCocoaErrorDomain"
                expect(nsError?.code) == 3840
                }

            it("treats top-level JSON that is not a dictionary or array as an error")
                {
                for atom in ["17", "\"foo\"", "null"]
                    {
                    NetworkStub.add(
                        .get, resource,
                        returning: HTTPResponse(
                            headers: ["Content-Type": "application/json"],
                            body: atom))
                    awaitFailure(resource().load())

                    expect(resource().latestError?.cause is RequestError.Cause.JSONResponseIsNotDictionaryOrArray) == true
                    }
                }

            it("can parse JSON atoms with custom configuration")
                {
                service().configure
                    { $0.pipeline[.parsing].removeTransformers() }

                service().configureTransformer("**", atStage: .parsing)
                    { try JSONSerialization.jsonObject(with: $0.content as Data, options: [.allowFragments]) }

                func expectJson<T: Equatable>(_ atom: String, toParseAs expectedValue: T)
                    {
                    NetworkStub.add(
                        .get, resource,
                        returning: HTTPResponse(
                            headers: ["Content-Type": "application/json"],
                            body: atom))
                    awaitNewData(resource().load())
                    expect(resource().latestData?.content as? T) == expectedValue
                    }
                expectJson("17",      toParseAs: 17)
                expectJson("\"foo\"", toParseAs: "foo")
                expectJson("null",    toParseAs: NSNull())
                }

            it("transforms error responses")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(
                        status: 500,
                        headers: ["Content-Type": "application/json"],
                        body: "{ \"error\": \"pigeon drove bus\" }"))
                awaitFailure(resource().load())
                expect(resource().latestError?.jsonDict as? [String:String])
                     == ["error": "pigeon drove bus"]
                }

            it("preserves root error if error response is unparsable")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(
                        status: 500,
                        headers: ["Content-Type": "application/json"],
                        body: "{ malformed JSON[[{{#$!@"))
                awaitFailure(resource().load())
                expect(resource().latestError?.userMessage) == "Internal server error"
                expect(resource().latestError?.entity?.content as? Data).notTo(beNil())
                }

            describe("via .jsonDict convenience")
                {
                it("gives JSON data")
                    {
                    stubJson()
                    expect(resource().jsonDict as NSObject) == jsonVal as NSObject
                    }

                it("gives empty dict for non-JSON response")
                    {
                    stubJson(contentType: "text/plain")
                    expect(resource().jsonDict as NSObject) == [:] as NSObject
                    }

                it("gives empty dict on error")
                    {
                    NetworkStub.add(.get, resource, status: 500)
                    expect(resource().jsonDict as NSObject) == [:] as NSObject
                    }
                }

            describe("via .jsonArray convenience")
                {
                it("gives JSON data")
                    {
                    NetworkStub.add(
                        .get, resource,
                        returning: HTTPResponse(
                            headers: ["Content-Type": "application/json"],
                            body: "[1,\"two\"]"))
                    awaitNewData(resource().load())
                    expect(resource().jsonArray as NSObject) == [1,"two"] as NSObject
                    }

                it("gives empty dict for non-dict response")
                    {
                    stubJson()
                    expect(resource().jsonArray as NSObject) == [] as NSObject
                    }
                }

            it("can log JSON-like container with non-JSON contents")
                {
                let notValidJSONObject: NSArray = [NSObject()]
                service().configureTransformer("**")
                    { (_: Entity<Any>) -> NSArray in notValidJSONObject }

                stubJson()
                expect(resource().typedContent()) === notValidJSONObject
                }
            }

        describe("image handling")
            {
            it("parses images")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(
                        headers: ["Content-Type": "image/gif"],
                        body: Data(base64Encoded: "R0lGODlhAQABAIAAAP///wAAACwAAAAAAQABAAACAkQBADs=")!))
                awaitNewData(resource().load())
                let image: Image? = resource().typedContent()
                expect(image).notTo(beNil())
                expect(image?.size) == CGSize(width: 1, height: 1)
                }

            it("gives an error for unparsable images")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(
                        headers: ["Content-Type": "image/gif"],
                        body: "Ceci n’est pas une image"))
                awaitFailure(resource().load())

                expect(resource().latestError?.cause is RequestError.Cause.UnparsableImage) == true
                }
            }

        describe("standard transformers")
            {
            let url = "test://pars.ing"

            func checkStandardParsing(for service: Service, json: Bool, text: Bool, images: Bool)
                {
                func stubMalformedResponse(contentType: String, expectSuccess: Bool)
                    {
                    let resource = service.resource(contentType)
                    NetworkStub.add(
                        .get, { resource },
                        returning: HTTPResponse(
                            headers: ["Content-Type": contentType],
                            body: Data([0xD8])))
                    let awaitRequest = expectSuccess ? awaitNewData : awaitFailure
                    awaitRequest(resource.load(), .inProgress)
                    expect(resource.latestData?.content is Data) == expectSuccess
                    }

                stubMalformedResponse(contentType: "application/json",          expectSuccess: !json)
                stubMalformedResponse(contentType: "text/plain; charset=utf-8", expectSuccess: !text)
                stubMalformedResponse(contentType: "image/png",                 expectSuccess: !images)
                }

            it("include JSON, text, and images by default")
                {
                checkStandardParsing(
                    for: Service(baseURL: url, networking: NetworkStub.defaultConfiguration),
                    json: true, text: true, images: true)
                }

            it("can be selectively disabled on Service creation")
                {
                checkStandardParsing(
                    for: Service(baseURL: url, standardTransformers: [.text, .image], networking: NetworkStub.defaultConfiguration),
                    json: false, text: true, images: true)
                checkStandardParsing(
                    for: Service(baseURL: url, standardTransformers: [.json], networking: NetworkStub.defaultConfiguration),
                    json: true, text: false, images: false)
                checkStandardParsing(
                    for: Service(baseURL: url, standardTransformers: [], networking: NetworkStub.defaultConfiguration),
                    json: false, text: false, images: false)
                }

            it("can be cleared and re-added in configuration")
                {
                let service = Service(baseURL: url, networking: NetworkStub.defaultConfiguration)
                service.configure
                    {
                    $0.pipeline.clear()
                    $0.pipeline.add(.text)
                    }

                checkStandardParsing(
                    for: service,
                    json: false, text: true, images: false)
                }
            }

        describe("custom transformer")
            {
            describe("using ResponseTransformer protocol")
                {
                let transformer = specVar { TestTransformer() }

                beforeEach
                    {
                    service().configure
                        { $0.pipeline[.parsing].add(transformer()) }
                    }

                it("can transform data")
                    {
                    stubText("greetings")
                    expect(resource().typedContent()) == "greetings processed"
                    expect(transformer().callCount) == 1
                    }

                it("can transform errors")
                    {
                    NetworkStub.add(.get, resource, status: 401)
                    awaitFailure(resource().load())
                    expect(resource().latestError?.userMessage) == "Unauthorized processed"
                    expect(transformer().callCount) == 1
                    }

                it("does not reprocess existing data on 304")
                    {
                    stubText("ahoy")

                    NetworkStub.clearAll()
                    NetworkStub.add(.get, resource, status: 304)
                    awaitNotModified(resource().load())

                    expect(resource().typedContent()) == "ahoy processed"
                    expect(transformer().callCount) == 1
                    }

                it("can modify headers")
                    {
                    stubText("ahoy")
                    expect(resource().latestData?.header(forKey: "x-cUSTOM-hEADER")) == "elztorpS"
                    }
                }

            describe("using closure")
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

                it("leaves errors untouched by default")
                    {
                    configureModelTransformer()
                    NetworkStub.add(
                        .get, resource,
                        returning: HTTPResponse(
                            status: 500,
                            headers: ["Content-Type": "text/plain"],
                            body: "I am not a model"))
                    awaitFailure(resource().load())
                    expect(resource().latestData).to(beNil())
                    expect(resource().latestError?.text) == "I am not a model"
                    }

                it("can transform errors")
                    {
                    service().configureTransformer("**", transformErrors: true)
                        { TestModel(name: $0.content) }
                    NetworkStub.add(
                        .get, resource,
                        returning: HTTPResponse(
                            status: 500,
                            headers: ["Content-Type": "text/plain"],
                            body: "Fred T. Error"))
                    awaitFailure(resource().load())
                    let model: TestModel? = resource().latestError?.typedContent()
                    expect(model?.name) == "Fred T. Error"
                    }

                context("with mismatched input type")
                    {
                    it("treats it as an error by default")
                        {
                        configureModelTransformer()

                        stubText("{}", contentType: "application/json", expectSuccess: false)
                        expect(resource().latestError?.cause is RequestError.Cause.WrongInputTypeInTranformerPipeline) == true
                        }

                    it("skips the transformer on .Skip")
                        {
                        service().configureTransformer("**", onInputTypeMismatch: .skip)
                            { TestModel(name: $0.content) }

                        stubText("{\"status\": \"untouched\"}", contentType: "application/json")
                        expect(resource().jsonDict["status"] as? String) == "untouched"
                        }

                    it("can skip the transformer with .SkipIfOutputTypeMatches")
                        {
                        service().configureTransformer("**")
                            { TestModel(name: $0.content + " Sr.") }
                        service().configureTransformer("**", atStage: .cleanup, onInputTypeMismatch: .skipIfOutputTypeMatches)
                            { TestModel(name: $0.content + " Jr.") }

                        stubText("Fred")
                        let model: TestModel? = resource().typedContent()
                        expect(model?.name) == "Fred Sr."
                        }

                    it("can flag output type mistmatch with .SkipIfOutputTypeMatches")
                        {
                        service().configureTransformer("**")
                            { [$0.content + " who is not a model"] }
                        service().configureTransformer("**", atStage: .cleanup, onInputTypeMismatch: .skipIfOutputTypeMatches)
                            { TestModel(name: $0.content + " Jr.") }

                        stubText("Fred", expectSuccess: false)
                        expect(resource().latestError?.cause is RequestError.Cause.WrongInputTypeInTranformerPipeline) == true
                        }
                    }

                it("can throw a custom error")
                    {
                    service().configureTransformer("**")
                        {
                        (_: Entity<String>) -> Date in
                        throw CustomError()
                        }

                    stubText("YUP", expectSuccess: false)
                    expect(resource().latestError?.cause is CustomError) == true
                    }

                it("can throw a RequestError")
                    {
                    service().configureTransformer("**")
                        {
                        (text: Entity<String>) -> Date in
                        throw RequestError(userMessage: "\(text.content) is broken", cause: CustomError())
                        }

                    stubText("Everything", expectSuccess: false)
                    expect(resource().latestError?.userMessage) == "Everything is broken"
                    expect(resource().latestError?.cause is CustomError) == true
                    }

                it("replaces previously configured model transformers by default")
                    {
                    configureModelTransformer()
                    service().configureTransformer("**")
                        { TestModel(name: "extra " + $0.content) }

                    stubText("wasabi")
                    let model: TestModel? = resource().typedContent()
                    expect(model?.name) == "extra wasabi"
                    }

                it("can append to previously configured model transformers")
                    {
                    configureModelTransformer()
                    service().configureTransformer("**", action: .appendToExisting)
                        {
                        (entity: Entity<TestModel>) -> TestModel in  // TODO: Why can’t Swift infer from $0.content here? Swift bug?
                        var model: TestModel = entity.content
                        model.name += " peas"
                        return model
                        }

                    stubText("wasabi")
                    let model: TestModel? = resource().typedContent()
                    expect(model?.name) == "wasabi peas"
                    }

                @discardableResult
                func stubTextRequest(_ string: String, method: RequestMethod) -> Entity<Any>
                    {
                    NetworkStub.add(
                        method,
                        resource,
                        returning: HTTPResponse(
                            headers: ["Content-Type": "text/plain"],
                            body: string))

                    var result: Entity<Any>?
                    let req = resource().request(method)
                    req.onSuccess { result = $0 }
                    awaitNewData(req)

                    return result!
                    }

                it("can be limited to specific HTTP request methods")
                    {
                    service().configureTransformer("**", requestMethods: [.put, .post])
                        { TestModel(name: $0.content) }

                    let getResult: String? = stubTextRequest("got it", method: .get).typedContent()
                    expect(getResult) == "got it"

                    let postResult: TestModel? = stubTextRequest("posted it", method: .post).typedContent()
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
                        expect(resource().latestError?.cause is RequestError.Cause.TransformerReturnedNil) == true
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

    fileprivate func process(_ response: Response) -> Response
        {
        callCount += 1
        switch response
            {
            case .success(var entity):
                entity.content = (entity.content as? String ?? "<non-string>") + " processed"
                if let header = entity.headers["x-custom-header"]
                    { entity.headers["x-custom-header"] = String(header.reversed()) }
                return .success(entity)

            case .failure(var error):
                error.userMessage += " processed"
                return .failure(error)
            }
        }
    }

private struct TestModel
    {
    var name: String

    init(name: String)
        { self.name = name }

    init?(anythingButOrange name: String)
        {
        guard name != "Orange" else
            { return nil }
        self.init(name: name)
        }
    }

private struct CustomError: Error { }
