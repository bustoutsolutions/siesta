//
//  RequestSpec.swift
//  Siesta
//
//  Created by Paul on 2016/8/14.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble
import Nocilla

class RequestSpec: ResourceSpecBase
    {
    override func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        {
        describe("Resource.request()")
            {
            it("initates a network call")
                {
                stubRequest(resource, "GET").andReturn(200)
                awaitNewData(resource().request(.GET))
                }

            it("handles various HTTP methods")
                {
                stubRequest(resource, "PATCH").andReturn(200)
                awaitNewData(resource().request(.PATCH))
                }

            it("sends headers from configuration")
                {
                service().configure { $0.config.headers["Zoogle"] = "frotz" }
                stubRequest(resource, "GET")
                    .withHeader("Zoogle", "frotz")
                    .andReturn(200)
                awaitNewData(resource().request(.GET))
                }

            describe("decorators")
                {
                it("are called for every request")
                    {
                    var beforeHookCount = 0
                    service().configure
                        {
                        $0.config.decorateRequests
                            {
                            res, req in
                            expect(res) === resource()
                            beforeHookCount += 1
                            return req
                            }
                        }

                    stubRequest(resource, "GET").andReturn(200)
                    stubRequest(resource, "POST").andReturn(200)
                    awaitNewData(resource().load())
                    awaitNewData(resource().request(.POST))

                    expect(beforeHookCount) == 2
                    }

                it("can attach request hooks")
                    {
                    var successHookCalled = false
                    service().configure
                        {
                        $0.config.decorateRequests
                            { $1.onSuccess { _ in successHookCalled = true } }
                        }

                    stubRequest(resource, "GET").andReturn(200)
                    awaitNewData(resource().load())

                    expect(successHookCalled) == true
                    }

                it("can preemptively cancel requests")
                    {
                    service().configure
                        {
                        $0.config.decorateRequests
                            {
                            $1.cancel()
                            return $1
                            }
                        }

                    awaitFailure(resource().load(), alreadyCompleted: true)  // Nocilla will flag if network call goes through
                    }

                context("substituting a request")
                    {
                    let dummyRequest = { Resource.failedRequest(Error(userMessage: "dummy", cause: DummyError())) }
                    let dummyReq0 = specVar { dummyRequest() },
                        dummyReq1 = specVar { dummyRequest() }

                    it("causes outside observers to see the replacement")
                        {
                        service().configure
                            {
                            $0.config.decorateRequests
                                {
                                $1.cancel()
                                return dummyReq0()
                                }
                            }

                        let req = resource().load()
                        expect(req) === dummyReq0()
                        awaitFailure(req, alreadyCompleted: true)
                        }

                    it("causes downstream decorators to see the replacement")
                        {
                        service().configure
                            {
                            $0.config.decorateRequests
                                {
                                expect($0) == resource()
                                $1.cancel()
                                return dummyReq0()  // passed here
                                }
                            $0.config.decorateRequests
                                {
                                expect($1) === dummyReq0()  // seen here
                                return dummyReq1()
                                }
                            }

                        let req = resource().load()
                        expect(req) === dummyReq1()
                        awaitFailure(req, alreadyCompleted: true)
                        }

                    it("does not start the original request if it was discarded")
                        {
                        service().configure
                            {
                            $0.config.decorateRequests
                                { _ in dummyReq0() }
                            }
                        awaitFailure(resource().load(), alreadyCompleted: true)  // Nocilla will flag if network call goes through
                        }

                    it("starts the original request if it is the first in a chain")
                        {
                        service().configure
                            {
                            $0.config.decorateRequests
                                {
                                _, req in req.chained
                                    {
                                    var responseInfo = $0
                                    guard case .Success(var entity) = responseInfo.response else
                                        { fatalError() }
                                    entity.content = entity.text + " redux"
                                    responseInfo.response = .Success(entity)
                                    return .UseResponse(responseInfo)
                                    }
                                }
                            }
                        stubRequest(resource, "GET").andReturn(200)
                            .withHeader("Content-Type", "text/plain")
                            .withBody("ducks")
                        awaitNewData(resource().load())
                        expect(resource().text) == "ducks redux"
                        }

                    func configureDeferredRequestChain(passToOriginalRequest passToOriginalRequest: Bool)
                        {
                        service().configure
                            {
                            $0.config.decorateRequests
                                {
                                _, req in
                                Resource.failedRequest(Error(userMessage: "dummy", cause: DummyError()))
                                    .chained
                                        {
                                        _ in if passToOriginalRequest
                                            { return .PassTo(req) }
                                        else
                                            { return .UseThisResponse }
                                        }
                                }
                            }
                        }

                    it("runs the original request if it is deferred but used by a chain")
                        {
                        configureDeferredRequestChain(passToOriginalRequest: true)
                        stubRequest(resource, "GET").andReturn(200)
                        awaitNewData(resource().load())
                        }

                    it("does not run the original request if it is unused by a chain")
                        {
                        configureDeferredRequestChain(passToOriginalRequest: false)
                        awaitFailure(resource().load())
                        }
                    }
                }
            }

        it("can be cancelled")
            {
            let reqStub = stubRequest(resource, "GET").andReturn(200).delay()
            let req = resource().request(.GET)
            req.onFailure
                { expect($0.cause is Error.Cause.RequestCancelled) == true }
            req.onCompletion
                { expect($0.response.isCancellation) == true }
            req.cancel()
            reqStub.go()
            awaitFailure(req, alreadyCompleted: true)
            }

        it(".cancel() has no effect if it already succeeded")
            {
            stubRequest(resource, "GET").andReturn(200)
            let req = resource().request(.GET)
            req.onCompletion
                { expect($0.response.isCancellation) == false }
            awaitNewData(req)
            req.cancel()
            awaitNewData(req, alreadyCompleted: true)
            }

        it(".cancel() has no effect if it never started")
            {
            let req = resource().request(.POST, json: ["unencodable": NSData()])
            req.onCompletion
                { expect($0.response.isCancellation) == false }
            awaitFailure(req, alreadyCompleted: true)
            req.cancel()
            }

        describe("repeated()")
            {
            func stubRepeatedRequest(answer: String = "No.", flavorHeader: String? = nil)
                {
                LSNocilla.sharedInstance().clearStubs()
                stubRequest(resource, "PATCH")
                    .withBody("Is there an echo in here?")
                    .withHeader("X-Flavor", flavorHeader)
                    .andReturn(200)
                    .withHeader("Content-Type", "text/plain")
                    .withBody(answer)
                }

            func expectResonseText(request: Request, text: String)
                {
                let expectation = QuickSpec.current().expectationWithDescription("response text")
                request.onSuccess
                    {
                    expectation.fulfill()
                    expect($0.typedContent()) == text
                    }
                QuickSpec.current().waitForExpectationsWithTimeout(1, handler: nil)
                }

            let oldRequest = specVar
                {
                () -> Request in
                stubRepeatedRequest()
                let req = resource().request(.PATCH, text: "Is there an echo in here?")
                awaitNewData(req)
                return req
                }

            let newRequest = specVar { oldRequest().repeated() }

            it("sends a new network request")
                {
                stubRepeatedRequest()
                awaitNewData(newRequest())
                }

            it("leaves the old request’s result intact")
                {
                oldRequest()
                stubRepeatedRequest("OK, maybe.")
                awaitNewData(newRequest())

                expectResonseText(oldRequest(), text: "No.")        // still has old result
                expectResonseText(newRequest(), text: "OK, maybe.") // has new result
                }

            it("does not call the old request’s callbacks")
                {
                var oldRequestHookCalls = 0
                oldRequest().onCompletion { _ in oldRequestHookCalls += 1 }

                stubRepeatedRequest()
                awaitNewData(newRequest())

                expect(oldRequestHookCalls) == 1
                }

            it("picks up header config changes")
                {
                var flavor: String? = nil
                service().configure
                    { $0.config.headers["X-Flavor"] = flavor }

                oldRequest()

                flavor = "iced maple ginger chcocolate pasta swirl"
                service().invalidateConfiguration()

                stubRepeatedRequest(flavorHeader: flavor)
                awaitNewData(newRequest())
                }

            it("repeats custom response mutation")
                {
                stubRepeatedRequest(flavorHeader: "mutant flavor 0")

                var mutationCount = 0
                let req = resource().request(.PATCH, text: "Is there an echo in here?")
                    {
                    expect($0.valueForHTTPHeaderField("X-Flavor")).to(beNil())
                    $0.setValue("mutant flavor \(mutationCount)", forHTTPHeaderField: "X-Flavor")
                    mutationCount += 1
                    }
                awaitNewData(req)

                stubRepeatedRequest(flavorHeader: "mutant flavor 1")
                awaitNewData(req.repeated())
                }

            it("does not repeat request decorations")
                {
                var decorations = 0
                service().configure
                    {
                    $0.config.decorateRequests
                        {
                        decorations += 1
                        return $1
                        }
                    }

                stubRepeatedRequest()
                awaitNewData(newRequest())

                expect(decorations) == 1
                }
            }

        describe("request body generation")
            {
            it("handles raw data")
                {
                let bytes: [UInt8] = [0x00, 0xFF, 0x17, 0xCA]
                let nsdata = NSData(bytes: bytes, length: bytes.count)

                stubRequest(resource, "POST")
                    .withHeader("Content-Type", "application/monkey")
                    .withBody(nsdata)
                    .andReturn(200)

                awaitNewData(resource().request(.POST, data: nsdata, contentType: "application/monkey"))
                }

            it("handles string data")
                {
                stubRequest(resource, "POST")
                    .withHeader("Content-Type", "text/plain; charset=utf-8")
                    .withBody("Très bien!")
                    .andReturn(200)

                awaitNewData(resource().request(.POST, text: "Très bien!"))
                }

            it("handles string encoding errors")
                {
                let req = resource().request(.POST, text: "Hélas!", encoding: NSASCIIStringEncoding)
                awaitFailure(req, alreadyCompleted: true)
                req.onFailure
                    {
                    let cause = $0.cause as? Error.Cause.UnencodableText
                    expect(cause?.encodingName) == "us-ascii"
                    expect(cause?.text) == "Hélas!"
                    }
                }

            it("handles JSON data")
                {
                stubRequest(resource, "PUT")
                    .withHeader("Content-Type", "application/json")
                    .withBody("{\"question\":[[2,\"be\"],[\"not\",2,\"be\"]]}")
                    .andReturn(200)

                awaitNewData(resource().request(.PUT, json: ["question": [[2, "be"], ["not", 2, "be"]]]))
                }

            it("handles JSON encoding errors")
                {
                let req = resource().request(.POST, json: ["question": [2, NSData()]])
                awaitFailure(req, alreadyCompleted: true)
                req.onFailure
                    { expect($0.cause is Error.Cause.InvalidJSONObject) == true }
                }

            context("with URL encoding")
                {
                it("encodes parameters")
                    {
                    stubRequest(resource, "PATCH")
                        .withHeader("Content-Type", "application/x-www-form-urlencoded")
                        .withBody("brown=cow&foo=bar&how=now")
                        .andReturn(200)

                    awaitNewData(resource().request(.PATCH, urlEncoded: ["foo": "bar", "how": "now", "brown": "cow"]))
                    }

                it("escapes unsafe characters")
                    {
                    stubRequest(resource, "PATCH")
                        .withHeader("Content-Type", "application/x-www-form-urlencoded")
                        .withBody("%E2%84%A5%3D%26=%E2%84%8C%E2%84%91%3D%26&f%E2%80%A2%E2%80%A2=b%20r")
                        .andReturn(200)

                    awaitNewData(resource().request(.PATCH, urlEncoded: ["f••": "b r", "℥=&": "ℌℑ=&"]))
                    }

                it("gives request failure for unencodable strings")
                    {
                    let bogus = String(
                        bytes: [0xD8, 0x00] as [UInt8],  // Unpaired surrogate char in UTF-16
                        encoding: NSUTF16BigEndianStringEncoding)!

                    for badParams in [[bogus: "foo"], ["foo": bogus]]
                        {
                        let req = resource().request(.PATCH, urlEncoded: badParams)
                        awaitFailure(req, alreadyCompleted: true)
                        req.onFailure
                            {
                            let cause = $0.cause as? Error.Cause.NotURLEncodable
                            expect(cause?.offendingString) == bogus
                            }
                        }
                    }
                }
            }

        describe("chained()")
            {
            func stubText(body: String, method: String = "GET") -> LSStubResponseDSL
                {
                return stubRequest(resource, method).andReturn(200)
                    .withHeader("Content-Type", "text/plain")
                    .withBody(body)
                }

            func expectResult(expectedResult: String, for req: Request, alreadyCompleted: Bool = false)
                {
                var actualResult: String? = nil
                req.onSuccess { actualResult = $0.text }
                awaitNewData(req, alreadyCompleted: alreadyCompleted)

                expect(actualResult) == expectedResult
                }

            let customResponse =
                ResponseInfo(
                    response: .Success(Entity(
                        content: "custom",
                        contentType: "text/special")))

            it("it can use the wrapped request’s response")
                {
                stubText("yo")
                let req = resource().request(.GET)
                    .chained { _ in .UseThisResponse }
                expectResult("yo", for: req)
                }

            it("it can use a custom response")
                {
                stubText("yo")
                let req = resource().request(.GET)
                    .chained { _ in .UseResponse(customResponse) }
                expectResult("custom", for: req)
                }

            it("it can chain to a new request")
                {
                stubText("yo")
                stubText("oy", method: "POST")
                let req = resource().request(.GET)
                    .chained { _ in .PassTo(resource().request(.POST)) }
                expectResult("oy", for: req)
                }

            it("it can repeat the request")
                {
                stubText("yo")
                let originalReq = resource().request(.GET)
                let chainedReq = originalReq.chained
                    {
                    _ in
                    LSNocilla.sharedInstance().clearStubs()
                    stubText("yoyo")
                    return .PassTo(originalReq.repeated())
                    }
                expectResult("yoyo", for: chainedReq)
                }

            it("isCompleted is false until a “use” action")
                {
                let reqStub = stubText("yo").delay()
                let req = resource().request(.GET).chained
                    { _ in .UseThisResponse }
                expect(req.isCompleted).to(beFalse())
                reqStub.go()
                expect(req.isCompleted).toEventually(beTrue())
                }

            describe("cancel()")
                {
                it("cancels the underlying request")
                    {
                    let reqStub = stubText("yo").delay()

                    let originalReq = resource().request(.GET)
                    let chainedReq = originalReq.chained
                        { _ in .UseThisResponse }
                    for req in [originalReq, chainedReq]
                        {
                        req.onCompletion
                            { expect($0.response.isCancellation) == true }
                        }

                    chainedReq.cancel()
                    reqStub.go()
                    awaitFailure(originalReq, alreadyCompleted: true)
                    }

                it("stops the chain from proceeding")
                    {
                    let reqStub = stubText("yo").delay()

                    let req = resource().request(.GET).chained
                        {
                        _ in
                        fail("should not be called")
                        return .UseThisResponse
                        }

                    req.cancel()
                    reqStub.go()
                    awaitFailure(req, alreadyCompleted: true)
                    }

                it("does not stop the chain if the underlying request is cancelled")
                    {
                    let reqStub = stubText("yo").delay()

                    let originalReq = resource().request(.GET)
                    let chainedReq = originalReq.chained
                        {
                        expect($0.response.isCancellation) == true
                        return .UseResponse(customResponse)
                        }

                    originalReq.cancel()
                    reqStub.go()
                    awaitFailure(originalReq, alreadyCompleted: true)
                    expectResult("custom", for: chainedReq, alreadyCompleted: true)
                    }
                }

            describe("repeated()")
                {
                it("restarts the chain at the restart point")
                    {
                    stubText("yo")
                    stubText("oy", method: "PATCH")

                    var responseCount = 0
                    let req = resource().request(.GET).chained
                        {
                        _ in
                        responseCount += 1
                        if responseCount == 1
                            { return .PassTo(resource().request(.PATCH)) }
                        else
                            { return .UseThisResponse }
                        }

                    expectResult("oy", for: req)
                    expectResult("yo", for: req.repeated())
                    expectResult("oy", for: req, alreadyCompleted: true)
                    }

                it("does not rerun chained requests wrapped outside of the restart")
                    {
                    stubText("yo")
                    stubText("oy", method: "PATCH")

                    var req0Count = 0, req1Count = 0
                    let req0 = resource().request(.GET).chained
                        {
                        _ in
                        req0Count += 1
                        return .UseThisResponse
                        }
                    let req1 = req0.chained
                        {
                        _ in
                        req1Count += 1
                        return .UseThisResponse
                        }

                    expectResult("yo", for: req1)
                    expectResult("yo", for: req0.repeated())
                    expect(req0Count) == 2
                    expect(req1Count) == 1
                    }
                }
            }
        }
    }

// MARK: - Helpers

private struct DummyError: ErrorType { }
