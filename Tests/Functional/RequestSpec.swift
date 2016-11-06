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
    override func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource)
        {
        describe("Resource.request()")
            {
            it("initates a network call")
                {
                _ = stubRequest(resource, "GET").andReturn(200)
                awaitNewData(resource().request(.get))
                }

            it("handles various HTTP methods")
                {
                _ = stubRequest(resource, "PATCH").andReturn(200)
                awaitNewData(resource().request(.patch))
                }

            it("sends headers from configuration")
                {
                service().configure { $0.headers["Zoogle"] = "frotz" }
                _ = stubRequest(resource, "GET")
                    .withHeader("Zoogle", "frotz")
                    .andReturn(200)
                awaitNewData(resource().request(.get))
                }

            describe("decorators")
                {
                it("are called for every request")
                    {
                    var beforeHookCount = 0
                    service().configure
                        {
                        $0.decorateRequests
                            {
                            res, req in
                            expect(res) === resource()
                            beforeHookCount += 1
                            return req
                            }
                        }

                    _ = stubRequest(resource, "GET").andReturn(200)
                    _ = stubRequest(resource, "POST").andReturn(200)
                    awaitNewData(resource().load())
                    awaitNewData(resource().request(.post))

                    expect(beforeHookCount) == 2
                    }

                it("can attach request hooks")
                    {
                    var successHookCalled = false
                    service().configure
                        {
                        $0.decorateRequests
                            { $1.onSuccess { _ in successHookCalled = true } }
                        }

                    _ = stubRequest(resource, "GET").andReturn(200)
                    awaitNewData(resource().load())

                    expect(successHookCalled) == true
                    }

                it("can preemptively cancel requests")
                    {
                    service().configure
                        {
                        $0.decorateRequests
                            {
                            $1.cancel()
                            return $1
                            }
                        }

                    awaitFailure(resource().load(), alreadyCompleted: true)  // Nocilla will flag if network call goes through
                    }

                context("substituting a request")
                    {
                    let dummyRequest = { Resource.failedRequest(RequestError(userMessage: "dummy", cause: DummyError())) }
                    let dummyReq0 = specVar { dummyRequest() },
                        dummyReq1 = specVar { dummyRequest() }

                    it("causes outside observers to see the replacement")
                        {
                        service().configure
                            {
                            $0.decorateRequests
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
                            $0.decorateRequests
                                {
                                expect($0) == resource()
                                $1.cancel()
                                return dummyReq0()  // passed here
                                }
                            $0.decorateRequests
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
                            $0.decorateRequests
                                { _ in dummyReq0() }
                            }
                        awaitFailure(resource().load(), alreadyCompleted: true)  // Nocilla will flag if network call goes through
                        }

                    it("starts the original request if it is the first in a chain")
                        {
                        service().configure
                            {
                            $0.decorateRequests
                                {
                                _, req in req.chained
                                    {
                                    var responseInfo = $0
                                    guard case .success(var entity) = responseInfo.response else
                                        { fatalError() }
                                    entity.content = entity.text + " redux"
                                    responseInfo.response = .success(entity)
                                    return .useResponse(responseInfo)
                                    }
                                }
                            }

                        _ = stubRequest(resource, "GET").andReturn(200)
                            .withHeader("Content-Type", "text/plain")
                            .withBody("ducks" as NSString)
                        awaitNewData(resource().load())
                        expect(resource().text) == "ducks redux"
                        }

                    func configureDeferredRequestChain(passToOriginalRequest: Bool)
                        {
                        service().configure
                            {
                            $0.decorateRequests
                                {
                                _, req in
                                Resource.failedRequest(RequestError(userMessage: "dummy", cause: DummyError()))
                                    .chained
                                        {
                                        _ in if passToOriginalRequest
                                            { return .passTo(req) }
                                        else
                                            { return .useThisResponse }
                                        }
                                }
                            }
                        }

                    it("runs the original request if it is deferred but used by a chain")
                        {
                        configureDeferredRequestChain(passToOriginalRequest: true)
                        _ = stubRequest(resource, "GET").andReturn(200)
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
            let req = resource().request(.get)
            req.onFailure
                { expect($0.cause is RequestError.Cause.RequestCancelled) == true }
            req.onCompletion
                { expect($0.response.isCancellation) == true }
            req.cancel()
            _ = reqStub.go()
            awaitFailure(req, alreadyCompleted: true)
            }

        it(".cancel() has no effect if it already succeeded")
            {
            _ = stubRequest(resource, "GET").andReturn(200)
            let req = resource().request(.get)
            req.onCompletion
                { expect($0.response.isCancellation) == false }
            awaitNewData(req)
            req.cancel()
            awaitNewData(req, alreadyCompleted: true)
            }

        it(".cancel() has no effect if it never started")
            {
            let req = resource().request(.post, json: ["unencodable": Data()])
            req.onCompletion
                { expect($0.response.isCancellation) == false }
            awaitFailure(req, alreadyCompleted: true)
            req.cancel()
            }

        describe("repeated()")
            {
            @discardableResult
            func stubRepeatedRequest(_ answer: String = "No.", flavorHeader: String? = nil)
                {
                LSNocilla.sharedInstance().clearStubs()
                _ = stubRequest(resource, "PATCH")
                    .withBody("Is there an echo in here?" as NSString)
                    .withHeader("X-Flavor", flavorHeader)
                    .andReturn(200)
                    .withHeader("Content-Type", "text/plain")
                    .withBody(answer as NSString)
                }

            func expectResonseText(_ request: Request, text: String)
                {
                let expectation = QuickSpec.current().expectation(description: "response text")
                request.onSuccess
                    {
                    expectation.fulfill()
                    expect($0.typedContent()) == text
                    }
                QuickSpec.current().waitForExpectations(timeout: 1, handler: nil)
                }

            let oldRequest = specVar
                {
                () -> Request in
                stubRepeatedRequest()
                let req = resource().request(.patch, text: "Is there an echo in here?")
                awaitNewData(req)
                return req
                }

            let repeatedRequest = specVar { oldRequest().repeated() }

            it("does not send the repeated request automatically")
                {
                _ = repeatedRequest()  // Nocilla will flag any request
                }

            it("sends a new network request on start()")
                {
                stubRepeatedRequest()
                awaitNewData(repeatedRequest().start())
                }

            it("leaves the old request’s result intact")
                {
                _ = oldRequest()
                stubRepeatedRequest("OK, maybe.")
                awaitNewData(repeatedRequest().start())

                expectResonseText(oldRequest(), text: "No.")        // still has old result
                expectResonseText(repeatedRequest(), text: "OK, maybe.") // has new result
                }

            it("does not call the old request’s callbacks")
                {
                var oldRequestHookCalls = 0
                oldRequest().onCompletion { _ in oldRequestHookCalls += 1 }

                stubRepeatedRequest()
                awaitNewData(repeatedRequest().start())

                expect(oldRequestHookCalls) == 1
                }

            it("picks up header config changes")
                {
                var flavor: String? = nil
                service().configure
                    { $0.headers["X-Flavor"] = flavor }

                _ = oldRequest()

                flavor = "iced maple ginger chcocolate pasta swirl"
                service().invalidateConfiguration()

                stubRepeatedRequest(flavorHeader: flavor)
                awaitNewData(repeatedRequest().start())
                }

            it("repeats custom response mutation")
                {
                stubRepeatedRequest(flavorHeader: "mutant flavor 0")

                var mutationCount = 0
                let req = resource().request(.patch, text: "Is there an echo in here?")
                    {
                    let flavor = $0.value(forHTTPHeaderField: "X-Flavor")
                    expect(flavor).to(beNil())
                    $0.setValue("mutant flavor \(mutationCount)", forHTTPHeaderField: "X-Flavor")
                    mutationCount += 1
                    }

                awaitNewData(req)

                stubRepeatedRequest(flavorHeader: "mutant flavor 1")
                awaitNewData(req.repeated().start())
                }

            it("does not repeat request decorations")
                {
                var decorations = 0
                service().configure
                    {
                    $0.decorateRequests
                        {
                        decorations += 1
                        return $1
                        }
                    }

                stubRepeatedRequest()
                awaitNewData(repeatedRequest().start())

                expect(decorations) == 1
                }
            }

        describe("request body generation")
            {
            it("handles raw data")
                {
                let bytes: [UInt8] = [0x00, 0xFF, 0x17, 0xCA]
                let nsdata = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)

                _ = stubRequest(resource, "POST")
                    .withHeader("Content-Type", "application/monkey")
                    .withBody(nsdata as NSData)
                    .andReturn(200)

                awaitNewData(resource().request(.post, data: nsdata, contentType: "application/monkey"))
                }

            it("handles string data")
                {
                _ = stubRequest(resource, "POST")
                    .withHeader("Content-Type", "text/plain; charset=utf-8")
                    .withBody("Très bien!" as NSString)
                    .andReturn(200)

                awaitNewData(resource().request(.post, text: "Très bien!"))
                }

            it("handles string encoding errors")
                {
                let req = resource().request(.post, text: "Hélas!", encoding: String.Encoding.ascii)
                awaitFailure(req, alreadyCompleted: true)
                req.onFailure
                    {
                    let cause = $0.cause as? RequestError.Cause.UnencodableText
                    expect(cause?.encoding) == String.Encoding.ascii
                    expect(cause?.text) == "Hélas!"
                    }
                }

            it("handles JSON data")
                {
                _ = stubRequest(resource, "PUT")
                    .withHeader("Content-Type", "application/json")
                    .withBody("{\"question\":[[2,\"be\"],[\"not\",2,\"be\"]]}" as NSString)
                    .andReturn(200)

                awaitNewData(resource().request(.put, json: ["question": [[2, "be"], ["not", 2, "be"]]]))
                }

            it("handles JSON encoding errors")
                {
                let req = resource().request(.post, json: ["question": [2, Data()]])
                awaitFailure(req, alreadyCompleted: true)
                req.onFailure
                    { expect($0.cause is RequestError.Cause.InvalidJSONObject) == true }
                }

            context("with URL encoding")
                {
                it("encodes parameters")
                    {
                    _ = stubRequest(resource, "PATCH")
                        .withHeader("Content-Type", "application/x-www-form-urlencoded")
                        .withBody("brown=cow&foo=bar&how=now" as NSString)
                        .andReturn(200)

                    awaitNewData(resource().request(.patch, urlEncoded: ["foo": "bar", "how": "now", "brown": "cow"]))
                    }

                it("escapes unsafe characters")
                    {
                    _ = stubRequest(resource, "PATCH")
                        .withHeader("Content-Type", "application/x-www-form-urlencoded")
                        .withBody("%E2%84%A5%3D%26=%E2%84%8C%E2%84%91%3D%26&f%E2%80%A2%E2%80%A2=b%20r" as NSString)
                        .andReturn(200)

                    awaitNewData(resource().request(.patch, urlEncoded: ["f••": "b r", "℥=&": "ℌℑ=&"]))
                    }

                it("gives request failure for unencodable strings")
                    {
                    let bogus = String(
                        bytes: [0xD8, 0x00] as [UInt8],  // Unpaired surrogate char in UTF-16
                        encoding: String.Encoding.utf16BigEndian)!

                    for badParams in [[bogus: "foo"], ["foo": bogus]]
                        {
                        let req = resource().request(.patch, urlEncoded: badParams)
                        awaitFailure(req, alreadyCompleted: true)
                        req.onFailure
                            {
                            let cause = $0.cause as? RequestError.Cause.NotURLEncodable
                            expect(cause?.offendingString) == bogus
                            }
                        }
                    }
                }
            }

        describe("chained()")
            {
            @discardableResult
            func stubText(_ body: String, method: String = "GET") -> LSStubResponseDSL
                {
                return stubRequest(resource, method).andReturn(200)
                    .withHeader("Content-Type", "text/plain")
                    .withBody(body as NSString)
                }

            func expectResult(_ expectedResult: String, for req: Request, alreadyCompleted: Bool = false)
                {
                var actualResult: String? = nil
                req.onSuccess { actualResult = $0.text }
                awaitNewData(req, alreadyCompleted: alreadyCompleted)

                expect(actualResult) == expectedResult
                }

            let customResponse =
                ResponseInfo(
                    response: .success(Entity<Any>(
                        content: "custom",
                        contentType: "text/special")))

            it("it can use the wrapped request’s response")
                {
                stubText("yo")
                let req = resource().request(.get)
                    .chained { _ in .useThisResponse }
                expectResult("yo", for: req)
                }

            it("it can use a custom response")
                {
                stubText("yo")
                let req = resource().request(.get)
                    .chained { _ in .useResponse(customResponse) }
                expectResult("custom", for: req)
                }

            it("it can chain to a new request")
                {
                stubText("yo")
                stubText("oy", method: "POST")
                let req = resource().request(.get)
                    .chained { _ in .passTo(resource().request(.post)) }
                expectResult("oy", for: req)
                }

            it("it can repeat the request")
                {
                stubText("yo")
                let originalReq = resource().request(.get)
                let chainedReq = originalReq.chained
                    {
                    _ in
                    LSNocilla.sharedInstance().clearStubs()
                    stubText("yoyo")
                    return .passTo(originalReq.repeated())
                    }
                expectResult("yoyo", for: chainedReq)
                }

            it("isCompleted is false until a “use” action")
                {
                let reqStub = stubText("yo").delay()
                let req = resource().request(.get).chained
                    { _ in .useThisResponse }
                expect(req.isCompleted).to(beFalse())
                _ = reqStub.go()
                expect(req.isCompleted).toEventually(beTrue())
                }

            describe("cancel()")
                {
                it("cancels the underlying request")
                    {
                    let reqStub = stubText("yo").delay()

                    let originalReq = resource().request(.get)
                    let chainedReq = originalReq.chained
                        { _ in .useThisResponse }
                    for req in [originalReq, chainedReq]
                        {
                        req.onCompletion
                            { expect($0.response.isCancellation) == true }
                        }

                    chainedReq.cancel()
                    _ = reqStub.go()
                    awaitFailure(originalReq, alreadyCompleted: true)
                    }

                it("stops the chain from proceeding")
                    {
                    let reqStub = stubText("yo").delay()

                    let req = resource().request(.get).chained
                        {
                        _ in
                        fail("should not be called")
                        return .useThisResponse
                        }

                    req.cancel()
                    _ = reqStub.go()
                    awaitFailure(req, alreadyCompleted: true)
                    }

                it("does not stop the chain if the underlying request is cancelled")
                    {
                    let reqStub = stubText("yo").delay()

                    let originalReq = resource().request(.get)
                    let chainedReq = originalReq.chained
                        {
                        expect($0.response.isCancellation) == true
                        return .useResponse(customResponse)
                        }

                    originalReq.cancel()
                    _ = reqStub.go()
                    awaitFailure(originalReq, alreadyCompleted: true)
                    expectResult("custom", for: chainedReq, alreadyCompleted: true)
                    }
                }

            describe("repeated()")
                {
                it("repeats the wrapped request")
                    {
                    stubText("yo")

                    let req = resource().request(.get).chained
                        {
                        if case .success(var entity) = $0.response
                            {
                            entity.content = "¡\(entity.text)!"
                            return .useResponse(ResponseInfo(response: .success(entity)))
                            }
                        else
                            { return .useThisResponse }
                        }

                    expectResult("¡yo!", for: req)

                    stubText("oy")
                    expectResult("¡oy!", for: req.repeated().start())
                    }

                it("reruns the chain’s logic afresh")
                    {
                    stubText("yo")
                    stubText("oy", method: "PATCH")

                    var responseCount = 0
                    let req = resource().request(.get).chained
                        {
                        _ in
                        responseCount += 1
                        if responseCount == 1
                            { return .passTo(resource().request(.patch)) }
                        else
                            { return .useThisResponse }
                        }

                    expectResult("oy", for: req)
                    expectResult("yo", for: req.repeated().start())
                    expectResult("oy", for: req, alreadyCompleted: true)
                    }

                it("does not rerun chained requests wrapped outside of the restart")
                    {
                    stubText("yo")
                    stubText("oy", method: "PATCH")

                    var req0Count = 0, req1Count = 0
                    let req0 = resource().request(.get).chained
                        {
                        _ in
                        req0Count += 1
                        return .useThisResponse
                        }
                    let req1 = req0.chained
                        {
                        _ in
                        req1Count += 1
                        return .useThisResponse
                        }

                    expectResult("yo", for: req1)
                    expectResult("yo", for: req0.repeated().start())
                    expect(req0Count) == 2
                    expect(req1Count) == 1
                    }
                }
            }
        }
    }

// MARK: - Helpers

private struct DummyError: Error { }
