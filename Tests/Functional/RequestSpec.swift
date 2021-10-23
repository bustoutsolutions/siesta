//
//  RequestSpec.swift
//  Siesta
//
//  Created by Paul on 2016/8/14.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta

import Foundation
import Quick
import Nimble

class RequestSpec: ResourceSpecBase
    {
    override func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource)
        {
        describe("Resource.request()")
            {
            it("initates a network call")
                {
                NetworkStub.add(.get, resource)
                awaitNewData(resource().request(.get))
                }

            it("handles various HTTP methods")
                {
                NetworkStub.add(.patch, resource)
                awaitNewData(resource().request(.patch))
                }

            for (method, httpCode) in [(RequestMethod.head, 200), (RequestMethod.post, 204)]
                {
                it("represents response without body as zero-length Data for \(method) → \(httpCode)")
                    {
                    NetworkStub.add(.head, resource)
                    let req = resource().request(.head)
                    awaitNewData(req)
                    req.onSuccess { expect($0.typedContent()) == Data() }
                    }
                }

            it("sends headers from configuration")
                {
                service().configure { $0.headers["Zoogle"] = "frotz" }
                NetworkStub.add(
                    matching: RequestPattern(
                        .get, resource,
                        headers: ["Zoogle": "frotz"]))
                awaitNewData(resource().request(.get))
                }

            describe("mutators")
                {
                it("can alter headers")
                    {
                    var malkoviches = ""
                    service().configure
                        {
                        $0.mutateRequests
                            {
                            malkoviches += "malkovich"
                            $0.setValue(malkoviches, forHTTPHeaderField: "X-Malkoviches")
                            }
                        }

                    for counter in ["malkovich", "malkovichmalkovich", "malkovichmalkovichmalkovich"]
                        {
                        NetworkStub.clearAll()
                        NetworkStub.add(
                            matching: RequestPattern(
                                .get, resource,
                                headers: ["X-Malkoviches": counter]))
                        awaitNewData(resource().request(.get))
                        }
                    }

                it("can read and alter the body")
                    {
                    service().configure
                        {
                        $0.mutateRequests
                            {
                            req in
                            if var body = req.httpBody
                                {
                                body += [42]
                                req.httpBody = body
                                req.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
                                }
                            }
                        }

                    NetworkStub.add(
                        matching: RequestPattern(
                            .post, resource,
                            headers: ["Content-Length": "4"],
                            body: Data([0, 1, 2, 42])))
                    awaitNewData(resource().request(.post, data: Data([0, 1, 2]), contentType: "foo/bar"))
                    }

                it("can alter the HTTP method, but this does not change mutators used")
                    {
                    service().configure(requestMethods: [.get])
                        {
                        $0.mutateRequests
                            { $0.setValue($0.httpMethod, forHTTPHeaderField: "Original-Method") }
                        $0.mutateRequests
                            { $0.httpMethod = "POST" }
                        $0.mutateRequests
                            { $0.setValue($0.httpMethod, forHTTPHeaderField: "Mutated-Method") }
                        }

                    var decorated = 0
                    service().configure(requestMethods: [.post])
                        {
                        $0.mutateRequests
                            { _ in fail("mutation should use original HTTP method only") }
                        $0.decorateRequests
                            {
                            decorated += 1
                            return $1
                            }
                        }

                    NetworkStub.add(
                        matching: RequestPattern(
                            .post, resource,
                            headers:
                                [
                                "Original-Method": "GET",
                                "Mutated-Method": "POST"
                                ]))
                    awaitNewData(resource().request(.get))
                    expect(decorated) == 1
                    }
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

                    NetworkStub.add(.get, resource)
                    NetworkStub.add(.post, resource)
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

                    NetworkStub.add(.get, resource)
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

                    awaitFailure(resource().load(), initialState: .completed)  // NetworkStub will flag if network call goes through
                    }

                context("substituting a request")
                    {
                    let dummyRequest = { Resource.failedRequest(returning: RequestError(userMessage: "dummy", cause: DummyError())) }
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
                        awaitFailure(req, initialState: .completed)
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
                        awaitFailure(req, initialState: .completed)
                        }

                    it("does not start the original request if it was discarded")
                        {
                        service().configure
                            {
                            $0.decorateRequests
                                { _,_  in dummyReq0() }
                            }
                        awaitFailure(resource().load(), initialState: .completed)  // NetworkStub will flag if network call goes through
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
                                        { fatalError("first request in chain should have succeeded") }
                                    entity.content = entity.text + " redux"
                                    responseInfo.response = .success(entity)
                                    return .useResponse(responseInfo)
                                    }
                                }
                            }

                        NetworkStub.add(
                            .get, resource,
                            returning: HTTPResponse(
                                headers: ["Content-Type": "text/plain"],
                                body: "ducks"))
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
                                Resource.failedRequest(returning: RequestError(userMessage: "dummy", cause: DummyError()))
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
                        NetworkStub.add(.get, resource)
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
            let reqStub = NetworkStub.add(.get, resource).delay()
            let req = resource().request(.get)
            req.onFailure
                { expect($0.cause is RequestError.Cause.RequestCancelled) == true }
            req.onCompletion
                { expect($0.response.isCancellation) == true }
            req.cancel()
            reqStub.go()
            awaitFailure(req, initialState: .completed)
            }

        it(".cancel() has no effect if it already succeeded")
            {
            NetworkStub.add(.get, resource)
            let req = resource().request(.get)
            req.onCompletion
                { expect($0.response.isCancellation) == false }
            awaitNewData(req)
            req.cancel()
            awaitNewData(req, initialState: .completed)
            }

        it(".cancel() has no effect if it never started")
            {
            let req = resource().request(.post, json: ["unencodable": Data()])
            req.onCompletion
                { expect($0.response.isCancellation) == false }
            awaitFailure(req, initialState: .completed)
            req.cancel()
            }

        describe("repeated()")
            {
            func stubRequest(_ answer: String = "No.", flavorHeader: String? = nil)
                {
                NetworkStub.clearAll()
                NetworkStub.add(
                    matching: RequestPattern(
                        .patch, resource,
                        headers: ["X-Flavor": flavorHeader],
                        body: "Is there an echo in here?"),
                    returning: HTTPResponse(
                        headers: ["Content-Type": "text/plain"],
                        body: answer))
                }

            func expectResonseText(_ request: Request, text: String)
                {
                let expectation = QuickSpec.current.expectation(description: "response text")
                request.onSuccess
                    {
                    expectation.fulfill()
                    expect($0.typedContent()) == text
                    }
                QuickSpec.current.waitForExpectations(timeout: 1)
                }

            let originalRequest = specVar
                {
                () -> Request in
                stubRequest()
                let req = resource().request(.patch, text: "Is there an echo in here?")
                awaitNewData(req)
                return req
                }

            let repeatedRequest = specVar { originalRequest().repeated() }

            it("does not send the repeated request automatically")
                {
                _ = originalRequest()  // Wait for original go through
                NetworkStub.clearAll() // Tell NetworkStub not to allow any more requests...
                _ = repeatedRequest()  // ...so that a request here would cause an error
                }

            it("sends a new network request on start()")
                {
                awaitNewData(repeatedRequest().start())
                }

            it("leaves the old request’s result intact")
                {
                _ = originalRequest()
                stubRequest("OK, maybe.")
                awaitNewData(repeatedRequest().start())

                expectResonseText(originalRequest(), text: "No.")        // still has old result
                expectResonseText(repeatedRequest(), text: "OK, maybe.") // has new result
                }

            it("does not call the old request’s callbacks")
                {
                var oldRequestHookCalls = 0
                originalRequest().onCompletion { _ in oldRequestHookCalls += 1 }

                awaitNewData(repeatedRequest().start())

                expect(oldRequestHookCalls) == 1
                }

            it("picks up header config changes")
                {
                var flavor: String?
                service().configure
                    { $0.headers["X-Flavor"] = flavor }

                _ = originalRequest()

                flavor = "iced maple ginger chcocolate pasta swirl"
                service().invalidateConfiguration()

                stubRequest(flavorHeader: flavor)
                awaitNewData(repeatedRequest().start())
                }

            it("repeats custom response mutation")
                {
                stubRequest(flavorHeader: "mutant flavor 0")

                var mutationCount = 0
                let req = resource().request(.patch, text: "Is there an echo in here?")
                    {
                    let flavor = $0.value(forHTTPHeaderField: "X-Flavor")
                    expect(flavor).to(beNil())
                    $0.setValue("mutant flavor \(mutationCount)", forHTTPHeaderField: "X-Flavor")
                    mutationCount += 1
                    }

                awaitNewData(req)

                stubRequest(flavorHeader: "mutant flavor 1")
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

                stubRequest()
                awaitNewData(repeatedRequest().start())

                expect(decorations) == 1
                }
            }

        describe("request body generation")
            {
            it("handles raw data")
                {
                let data = Data([0x00, 0xFF, 0x17, 0xCA])

                NetworkStub.add(
                    matching: RequestPattern(
                        .post, resource,
                        headers: ["Content-Type": "application/monkey"],
                        body: data))

                awaitNewData(resource().request(.post, data: data, contentType: "application/monkey"))
                }

            it("handles string data")
                {
                NetworkStub.add(
                    matching: RequestPattern(
                        .post, resource,
                        headers: ["Content-Type": "text/plain; charset=utf-8"],
                        body: "Très bien!"))

                awaitNewData(resource().request(.post, text: "Très bien!"))
                }

            it("handles string encoding errors")
                {
                let req = resource().request(.post, text: "Hélas!", encoding: String.Encoding.ascii)
                awaitFailure(req, initialState: .completed)
                req.onFailure
                    {
                    let cause = $0.cause as? RequestError.Cause.UnencodableText
                    expect(cause?.encoding) == String.Encoding.ascii
                    expect(cause?.text) == "Hélas!"
                    }
                }

            it("handles JSON data")
                {
                NetworkStub.add(
                    matching: RequestPattern(
                        .put, resource,
                        headers: ["Content-Type": "application/json"],
                        body: #"{"question":[[2,"be"],["not",2,"be"]]}"#))

                awaitNewData(resource().request(.put, json: ["question": [[2, "be"], ["not", 2, "be"]]]))
                }

            it("handles JSON encoding errors")
                {
                let req = resource().request(.post, json: ["question": [2, Data()]])
                awaitFailure(req, initialState: .completed)
                req.onFailure
                    { expect($0.cause is RequestError.Cause.InvalidJSONObject) == true }
                }

            context("with URL encoding")
                {
                it("encodes parameters")
                    {
                    NetworkStub.add(
                        matching: RequestPattern(
                            .patch, resource,
                            headers: ["Content-Type": "application/x-www-form-urlencoded"],
                            body: "brown=cow&foo=bar&how=now"))

                    awaitNewData(resource().request(.patch, urlEncoded: ["foo": "bar", "how": "now", "brown": "cow"]))
                    }

                it("escapes unsafe characters")
                    {
                    NetworkStub.add(
                        matching: RequestPattern(
                            .patch, resource,
                            headers: ["Content-Type": "application/x-www-form-urlencoded"],
                            body: "%E2%84%A5%3D%26=%E2%84%8C%E2%84%91%3D%26&f%E2%80%A2%E2%80%A2=b%20r"))

                    awaitNewData(resource().request(.patch, urlEncoded: ["f••": "b r", "℥=&": "ℌℑ=&"]))
                    }

                it("gives request failure for unencodable strings")
                    {
                    let bogus = String(
                        bytes: [0xD8, 0x00],  // Unpaired surrogate char in UTF-16
                        encoding: String.Encoding.utf16BigEndian)!

                    for badParams in [[bogus: "foo"], ["foo": bogus]]
                        {
                        let req = resource().request(.patch, urlEncoded: badParams)
                        awaitFailure(req, initialState: .completed)
                        req.onFailure
                            {
                            let cause = $0.cause as? RequestError.Cause.NotURLEncodable
                            expect(cause?.offendingString) == bogus
                            }
                        }
                    }
                }

            it("overrides any Content-Type set in configuration headers")
                {
                service().configure { $0.headers["Content-Type"] = "frotzle/ooglatz" }
                NetworkStub.add(
                    matching: RequestPattern(
                        .post, resource,
                        headers: ["Content-Type": "application/json"],
                        body: #"{"foo":"bar"}"#))
                awaitNewData(resource().request(.post, json: ["foo": "bar"]))
                }

            it("lets ad hoc request mutation override the Content-Type")
                {
                NetworkStub.add(
                    matching: RequestPattern(
                        .post, resource,
                        headers: ["Content-Type": "person/json"],
                        body: #"{"foo":"bar"}"#))
                let req = resource().request(.post, json: ["foo": "bar"])
                    { $0.setValue("person/json", forHTTPHeaderField: "Content-Type") }
                awaitNewData(req)
                }

            it("lets configured mutators override the Content-Type")
                {
                service().configure
                    {
                    $0.mutateRequests
                        { $0.setValue("argonaut/json", forHTTPHeaderField: "Content-Type") }  // This one wins, even though...
                    }

                NetworkStub.add(
                    matching: RequestPattern(
                        .post, resource,
                        headers: ["Content-Type": "argonaut/json"],
                        body: #"{"foo":"bar"}"#))
                let req = resource().request(.post, json: ["foo": "bar"])                     // ...request(json:) sets it to "application/json"...
                    { $0.setValue("person/json", forHTTPHeaderField: "Content-Type") }        // ...and ad hoc mutation overrides that.
                awaitNewData(req)
                }
            }

        describe("chained()")
            {
            @discardableResult
            func stubText(_ body: String, method: RequestMethod = .get) -> RequestStub
                {
                NetworkStub.add(
                    method,
                    resource,
                    returning: HTTPResponse(
                        headers: ["Content-Type": "text/plain"],
                        body: body))
                }

            func expectResult(_ expectedResult: String, for req: Request, initialState: RequestState = .inProgress)
                {
                var actualResult: String?
                req.onSuccess { actualResult = $0.text }
                awaitNewData(req, initialState: initialState)

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
                stubText("oy", method: .post)
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
                    NetworkStub.clearAll()
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
                expect(req.state) == .inProgress
                reqStub.go()
                expect(req.state).toEventually(equal(.completed))
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
                    reqStub.go()
                    awaitFailure(originalReq, initialState: .completed)
                    }

                it("stops the chain from proceeding")
                    {
                    let reqStub = stubText("yo").delay()

                    let originalReq = resource().request(.get)
                    let chainedReq = originalReq.chained
                        {
                        _ in
                        fail("should not be called")
                        return .useThisResponse
                        }

                    chainedReq.cancel()
                    awaitFailure(chainedReq, initialState: .completed)
                    reqStub.go()
                    awaitFailure(originalReq, initialState: .completed)
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
                    reqStub.go()
                    awaitFailure(originalReq, initialState: .completed)
                    expectResult("custom", for: chainedReq, initialState: .completed)
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
                    stubText("oy", method: .patch)

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
                    expectResult("oy", for: req, initialState: .completed)
                    }

                it("does not rerun chained requests wrapped outside of the restart")
                    {
                    stubText("yo")
                    stubText("oy", method: .patch)

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

        describe("with custom delegate")
            {
            let dummyResponse =
                ResponseInfo(
                    response: .success(Entity<Any>(
                        content: "dummy response",
                        contentType: "text/whatever")))

            it("doesn't automatically start")
                {
                let delegate = RequestDelegateStub
                    { _ in fail("should not execute") }
                _ = Resource.prepareRequest(using: delegate)
                }

            it("doesn't complete until completion handler called")
                {
                let delegate = RequestDelegateStub
                    { _ in }
                _ = Resource.prepareRequest(using: delegate)
                    .onCompletion { _ in fail("should not execute") }
                    .start()
                }

            it("yields the response from the completion handler")
                {
                let delegate = RequestDelegateStub
                    { $0.broadcastResponse(dummyResponse) }
                let req = Resource.prepareRequest(using: delegate)
                    .onSuccess { expect($0.content as? String) == "dummy response" }
                    .start()
                awaitNewData(req, initialState: .completed)
                }

            it("will ignore the response after one is already broadcast")
                {
                let delegate = RequestDelegateStub
                    {
                    completionHandler in
                    expect(completionHandler.willIgnore(dummyResponse)) == false
                    completionHandler.broadcastResponse(dummyResponse)
                    expect(completionHandler.willIgnore(dummyResponse)) == true
                    }
                Resource.prepareRequest(using: delegate).start()
                }

            // TODO: What else needs testing here?
            }
        }
    }

// MARK: - Helpers

private struct DummyError: Error { }

private class RequestDelegateStub: RequestDelegate
    {
    private let startOperation: (RequestCompletionHandler) -> Void

    init(startOperation: @escaping (RequestCompletionHandler) -> Void)
        { self.startOperation = startOperation }

    func startUnderlyingOperation(passingResponseTo completionHandler: RequestCompletionHandler)
        { startOperation(completionHandler) }

    func cancelUnderlyingOperation()
        { }

    func repeated() -> RequestDelegate
        { fatalError("unsupported") }

    let requestDescription = "DummyRequestDelegate"
    }
