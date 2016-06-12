//
//  ResourceRequestsSpec.swift
//  Siesta
//
//  Created by Paul on 2015/7/5.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble
import Nocilla

class ResourceRequestsSpec: ResourceSpecBase
    {
    override func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        {
        it("starts in a blank state")
            {
            expect(resource().latestData).to(beNil())
            expect(resource().latestError).to(beNil())

            expect(resource().isLoading) == false
            expect(resource().allRequests).to(beIdentialObjects([]))
            expect(resource().loadRequests).to(beIdentialObjects([]))
            }

        describe("request()")
            {
            it("fetches the resource")
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

            describe("beforeStartingRequest hook from configuation")
                {
                it("is called for every request")
                    {
                    var beforeHookCount = 0
                    service().configure
                        {
                        $0.config.beforeStartingRequest
                            {
                            res, req in
                            expect(res) === resource()
                            beforeHookCount += 1
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
                        $0.config.beforeStartingRequest
                            { $1.onSuccess { _ in successHookCalled = true } }
                        }

                    stubRequest(resource, "GET").andReturn(200)
                    awaitNewData(resource().load())

                    expect(successHookCalled) == true
                    }

                it("can cancel requests")
                    {
                    service().configure
                        {
                        $0.config.beforeStartingRequest
                            { $1.cancel() }
                        }

                    awaitFailure(resource().load(), alreadyCompleted: true)  // Nocilla will flag if network call goes through
                    }
                }

            it("does not update the resource state")
                {
                stubRequest(resource, "GET").andReturn(200)
                awaitNewData(resource().request(.GET))
                expect(resource().latestData).to(beNil())
                expect(resource().latestError).to(beNil())
                }

            it("can be cancelled")
                {
                let reqStub = stubRequest(resource, "GET").andReturn(200).delay()
                let req = resource().request(.GET)
                req.onFailure
                    { expect($0.cause is Error.Cause.RequestCancelled) == true }
                req.onCompletion
                    { expect($0.isCancellation) == true }
                req.cancel()
                reqStub.go()
                awaitFailure(req, alreadyCompleted: true)
                }

            it(".cancel() has no effect if it already succeeded")
                {
                stubRequest(resource, "GET").andReturn(200)
                let req = resource().request(.GET)
                req.onCompletion
                    { expect($0.isCancellation) == false }
                awaitNewData(req)
                req.cancel()
                awaitNewData(req, alreadyCompleted: true)
                }

            it(".cancel() has no effect if it never started")
                {
                let req = resource().request(.POST, json: ["unencodable": NSData()])
                req.onCompletion
                    { expect($0.isCancellation) == false }
                awaitFailure(req, alreadyCompleted: true)
                req.cancel()
                }

            // TODO: How to reproduce these conditions in tests?
            pending("server response has no effect if it arrives but cancel() already called") { }
            pending("cancel() has no effect after request completed") { }

            it("tracks concurrent requests")
                {
                func stubDelayedAndRequest(ident: String) -> (LSStubResponseDSL, Request)
                    {
                    let reqStub = stubRequest(resource, "GET")
                        .withHeader("Request-ident", ident)
                        .andReturn(200)
                        .delay()
                    let req = resource().request(.GET)
                        { $0.setValue(ident, forHTTPHeaderField: "Request-ident") }
                    return (reqStub, req)
                    }

                let (reqStub0, req0) = stubDelayedAndRequest("zero"),
                    (reqStub1, req1) = stubDelayedAndRequest("one")

                expect(resource().isRequesting) == true
                expect(resource().allRequests).to(beIdentialObjects([req0, req1]))

                reqStub0.go()
                awaitNewData(req0)
                expect(resource().isRequesting) == true
                expect(resource().allRequests).to(beIdentialObjects([req1]))

                reqStub1.go()
                awaitNewData(req1)
                expect(resource().isLoading) == false
                expect(resource().allRequests).to(beIdentialObjects([]))
                }

            context("POST/PUT/PATCH body")
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

                context("with a URL-encoded body")
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

                    it("give request failure for unencodable strings")
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
            }

        describe("load()")
            {
            it("marks that the resource is loading")
                {
                expect(resource().isLoading) == false

                stubRequest(resource, "GET").andReturn(200)
                let req = resource().load()
                expect(resource().isLoading) == true

                awaitNewData(req)
                expect(resource().isLoading) == false
                }

            it("stores the response data")
                {
                stubRequest(resource, "GET").andReturn(200)
                    .withBody("eep eep")
                awaitNewData(resource().load())

                expect(resource().latestData).notTo(beNil())
                expect(dataAsString(resource().latestData?.content)) == "eep eep"
                }

            it("stores the content type")
                {
                stubRequest(resource, "GET").andReturn(200)
                    .withHeader("cOnTeNt-TyPe", "text/monkey")
                awaitNewData(resource().load())

                expect(resource().latestData?.contentType) == "text/monkey"
                }

            it("extracts the charset if present")
                {
                stubRequest(resource, "GET").andReturn(200)
                    .withHeader("Content-type", "text/monkey; charset=utf-8")
                awaitNewData(resource().load())

                expect(resource().latestData?.charset) == "utf-8"
                }

            it("includes the charset in the content type")
                {
                stubRequest(resource, "GET").andReturn(200)
                    .withHeader("Content-type", "text/monkey; charset=utf-8")
                awaitNewData(resource().load())

                expect(resource().latestData?.contentType) == "text/monkey; charset=utf-8"
                }

            it("parses the charset")
                {
                let monkeyType = "text/monkey; body=fuzzy; charset=euc-jp; arms=long"
                stubRequest(resource, "GET").andReturn(200)
                    .withHeader("Content-type", monkeyType)
                awaitNewData(resource().load())

                expect(resource().latestData?.contentType) == monkeyType
                expect(resource().latestData?.charset) == "euc-jp"
                }

            it("defaults content type to raw binary")
                {
                stubRequest(resource, "GET").andReturn(200)
                awaitNewData(resource().load())

                // Although Apple's NSURLResponse.contentType defaults to text/plain,
                // the correct default content type for HTTP is application/octet-stream.
                // http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.2.1

                expect(resource().latestData?.contentType) == "application/octet-stream"
                }

            it("stores headers")
                {
                stubRequest(resource, "GET").andReturn(200)
                    .withHeader("Personal-Disposition", "Quirky")
                awaitNewData(resource().load())

                expect(resource().latestData?.header("Personal-Disposition")) == "Quirky"
                expect(resource().latestData?.header("pErsonal-dIsposition")) == "Quirky"
                expect(resource().latestData?.header("pErsonaldIsposition")).to(beNil())
                }

            it("handles missing etag")
                {
                stubRequest(resource, "GET").andReturn(200)
                awaitNewData(resource().load())

                expect(resource().latestData?.etag).to(beNil())
                }

            func sendAndWaitForSuccessfulRequest()
                {
                stubRequest(resource, "GET")
                    .andReturn(200)
                    .withHeader("eTaG", "123 456 xyz")
                    .withHeader("Content-Type", "applicaiton/zoogle+plotz")
                    .withBody("zoogleplotz")
                awaitNewData(resource().load())
                LSNocilla.sharedInstance().clearStubs()
                }

            func expectDataToBeUnchanged()
                {
                expect(dataAsString(resource().latestData?.content)) == "zoogleplotz"
                expect(resource().latestData?.contentType) == "applicaiton/zoogle+plotz"
                expect(resource().latestData?.etag) == "123 456 xyz"
                }

            context("receiving an etag")
                {
                beforeEach(sendAndWaitForSuccessfulRequest)

                it("stores the etag")
                    {
                    expect(resource().latestData?.etag) == "123 456 xyz"
                    }

                it("sends the etag with subsequent requests")
                    {
                    stubRequest(resource, "GET")
                        .withHeader("If-None-Match", "123 456 xyz")
                        .andReturn(304)
                    awaitNotModified(resource().load())
                    }

                it("handles subsequent 200 by replacing data")
                    {
                    stubRequest(resource, "GET")
                        .andReturn(200)
                        .withHeader("eTaG", "ABC DEF 789")
                        .withHeader("Content-Type", "applicaiton/ploogle+zotz")
                        .withBody("plooglezotz")
                    awaitNewData(resource().load())

                    expect(dataAsString(resource().latestData?.content)) == "plooglezotz"
                    expect(resource().latestData?.contentType) == "applicaiton/ploogle+zotz"
                    expect(resource().latestData?.etag) == "ABC DEF 789"
                    }

                it("handles subsequent 304 by keeping existing data")
                    {
                    stubRequest(resource, "GET").andReturn(304)
                    awaitNotModified(resource().load())

                    expectDataToBeUnchanged()
                    expect(resource().latestError).to(beNil())
                    }
                }

            it("handles request errors")
                {
                let sampleError = NSError(domain: "TestDomain", code: 12345, userInfo: nil)
                stubRequest(resource, "GET").andFailWithError(sampleError)
                awaitFailure(resource().load())

                expect(resource().latestData).to(beNil())
                expect(resource().latestError).notTo(beNil())
                expect(resource().latestError?.cause as? NSError) == sampleError
                }

            // Testing all these HTTP codes individually because Apple likes
            // to treat specific ones as special cases.

            for statusCode in Array(400...410) + (500...505)
                {
                it("treats HTTP \(statusCode) as an error")
                    {
                    stubRequest(resource, "GET").andReturn(statusCode)
                    awaitFailure(resource().load())

                    expect(resource().latestData).to(beNil())
                    expect(resource().latestError).notTo(beNil())
                    expect(resource().latestError?.httpStatusCode) == statusCode
                    }
                }

            it("preserves last valid data after error")
                {
                sendAndWaitForSuccessfulRequest()

                stubRequest(resource, "GET").andReturn(500)
                awaitFailure(resource().load())

                expectDataToBeUnchanged()
                }

            it("leaves everything unchanged after a cancelled request")
                {
                sendAndWaitForSuccessfulRequest()

                let reqStub = stubRequest(resource, "GET").andReturn(200).delay()
                let req = resource().load()
                req.cancel()
                reqStub.go()
                awaitFailure(req, alreadyCompleted: true)

                expectDataToBeUnchanged()
                expect(resource().latestError).to(beNil())
                }

            // TODO: test no internet connnection if possible

            it("generates error messages from NSError message")
                {
                let sampleError = NSError(
                    domain: "TestDomain", code: 12345,
                    userInfo: [NSLocalizedDescriptionKey: "KABOOM"])
                stubRequest(resource, "GET").andFailWithError(sampleError)
                awaitFailure(resource().load())

                expect(resource().latestError?.userMessage) == "KABOOM"
                }

            it("generates error messages from HTTP status codes")
                {
                stubRequest(resource, "GET").andReturn(404)
                awaitFailure(resource().load())

                expect(resource().latestError?.userMessage) == "Not found"
                }

            // TODO: how should it handle redirects?
            }

        describe("loadIfNeeded()")
            {
            func expectToLoad(@autoclosure reqClosure: () -> Request?, returning loadReq: Request? = nil)
                {
                stubRequest(resource, "GET").andReturn(200) // Stub first...
                let reqReturned = reqClosure()             // ...then allow loading
                expect(resource().isLoading) == true
                expect(reqReturned).notTo(beNil())
                if loadReq != nil
                    {
                    expect(reqReturned as? AnyObject)
                         === loadReq as? AnyObject
                    }
                if let reqReturned = reqReturned
                    { awaitNewData(reqReturned) }
                }

            func expectNotToLoad(req: Request?)
                {
                expect(req).to(beNil())
                expect(resource().isLoading) == false
                }

            it("loads a resource never before loaded")
                {
                expectToLoad(resource().loadIfNeeded())
                }

            it("returns the existing request if one is already in progress")
                {
                stubRequest(resource, "GET").andReturn(200)
                let existingReq = resource().load()
                expectToLoad(resource().loadIfNeeded(), returning: existingReq)
                }

            it("initiates a new request if a non-load request is in progress")
                {
                let postReqStub = stubRequest(resource, "POST").andReturn(200).delay(),
                    loadReqStub = stubRequest(resource, "GET").andReturn(200).delay()
                let postReq = resource().request(.POST),
                    loadReq = resource().loadIfNeeded()

                expect(loadReq).toNot(beNil())

                postReqStub.go()
                awaitNewData(postReq)
                loadReqStub.go()
                awaitNewData(loadReq!)
                }

            context("with data present")
                {
                beforeEach
                    {
                    setResourceTime(1000)
                    expectToLoad(resource().load())
                    }

                it("does not load again soon")
                    {
                    setResourceTime(1010)
                    expectNotToLoad(resource().loadIfNeeded())
                    }

                it("loads again later")
                    {
                    setResourceTime(2000)
                    expectToLoad(resource().loadIfNeeded())
                    }

                it("respects custom expiration time")
                    {
                    service().configure("**") { $0.config.expirationTime = 1 }
                    setResourceTime(1002)
                    expectToLoad(resource().loadIfNeeded())
                    }
                }

            context("with an error present")
                {
                beforeEach
                    {
                    setResourceTime(1000)
                    stubRequest(resource, "GET").andReturn(404)
                    awaitFailure(resource().load())
                    LSNocilla.sharedInstance().clearStubs()
                    }

                it("does not retry soon")
                    {
                    setResourceTime(1001)
                    expectNotToLoad(resource().loadIfNeeded())
                    }

                it("retries later")
                    {
                    setResourceTime(2000)
                    expectToLoad(resource().loadIfNeeded())
                    }

                it("respects custom retry time")
                    {
                    service().configure("**") { $0.config.retryTime = 1 }
                    setResourceTime(1002)
                    expectToLoad(resource().loadIfNeeded())
                    }
                }
            }

        describe("load(usingRequest:)")
            {
            let request = specVar { resource().request(.POST) }

            beforeEach
                {
                stubRequest(resource, "POST")
                    .andReturn(200)
                    .withHeader("Content-type", "text/plain")
                    .withBody("Posted!")
                }

            it("updates resource state")
                {
                awaitNewData(resource().load(usingRequest: request()))
                expect(resource().text) == "Posted!"
                }

            it("notifies observers")
                {
                var observerNotified = false
                resource().addObserver(owner: request())
                    { _ in observerNotified = true }

                resource().load(usingRequest: request())

                awaitNewData(request())
                expect(observerNotified) == true
                }
            }

        describe("cancelLoadIfUnobserved()")
            {
            let reqStub = specVar { stubRequest(resource, "GET").andReturn(200).delay() }
            let req = specVar { resource().load() }
            var owner: AnyObject?

            beforeEach
                {
                reqStub()
                req()
                owner = DummyObject()
                resource().addObserver(owner: owner!) { _ in }
                owner = DummyObject() // replaces old one
                // Resource now has outstanding load request & no observers
                }

            afterEach
                { owner = nil }

            it("cancels if resource has no observers")
                {
                resource().cancelLoadIfUnobserved()

                reqStub().go()
                awaitFailure(req(), alreadyCompleted: true)
                }

            it("does not cancel if resource has an observer")
                {
                resource().addObserver(owner: owner!) { _ in }
                resource().cancelLoadIfUnobserved()

                reqStub().go()
                awaitNewData(req())
                }

            it("cancels multiple load requests")
                {
                let req0 = resource().load(),
                    req1 = resource().load()

                resource().cancelLoadIfUnobserved()

                reqStub().go()
                awaitFailure(req0, alreadyCompleted: true)
                awaitFailure(req1, alreadyCompleted: true)
                }

            context("(afterDelay:)")
                {
                it("cancels load if resource has loses observers during delay")
                    {
                    let expectation = QuickSpec.current().expectationWithDescription("cancelLoadIfUnobserved(afterDelay:")
                    resource().addObserver(owner: owner!) { _ in }
                    resource().cancelLoadIfUnobserved(afterDelay: 0.001)
                        { expectation.fulfill() }
                    owner = nil
                    QuickSpec.current().waitForExpectationsWithTimeout(1, handler: nil)

                    reqStub().go()
                    awaitFailure(req(), alreadyCompleted: true)
                    }

                it("does not cancel load if resource gains an observer during delay")
                    {
                    let expectation = QuickSpec.current().expectationWithDescription("cancelLoadIfUnobserved(afterDelay:")
                    resource().cancelLoadIfUnobserved(afterDelay: 0.001)
                        { expectation.fulfill() }
                    resource().addObserver(owner: owner!) { _ in }
                    QuickSpec.current().waitForExpectationsWithTimeout(1, handler: nil)

                    reqStub().go()
                    awaitNewData(req())
                    }
                }
            }

        describe("overrideLocalData()")
            {
            let arbitraryContentType = "content-can-be/anything"
            let arbitraryContent = specVar { NSCalendar(calendarIdentifier: NSCalendarIdentifierEthiopicAmeteMihret) as! AnyObject }
            let localData = specVar { Entity(content: arbitraryContent(), contentType: arbitraryContentType) }

            it("updates the data")
                {
                resource().overrideLocalData(localData())
                expect(resource().latestData?.content as? AnyObject) === arbitraryContent()
                expect(resource().latestData?.contentType) == arbitraryContentType
                }

            it("clears the latest error")
                {
                stubRequest(resource, "GET").andReturn(500)
                awaitFailure(resource().load())
                expect(resource().latestError).notTo(beNil())

                resource().overrideLocalData(localData())
                expect(resource().latestData).notTo(beNil())
                expect(resource().latestError).to(beNil())
                }

            it("does not touch the transformer pipeline")
                {
                let rawData = "a string".dataUsingEncoding(NSASCIIStringEncoding)
                resource().overrideLocalData(Entity(content: rawData!, contentType: "text/plain"))
                expect(resource().latestData?.content as? NSData) === rawData
                }
            }

        describe("overrideLocalContent()")
            {
            it("updates latestData’s content without altering headers")
                {
                stubRequest(resource, "GET")
                    .andReturn(200)
                    .withHeader("Content-type", "food/pasta")
                    .withHeader("Sauce-disposition", "garlic")
                    .withBody("linguine")

                awaitNewData(resource().load())

                resource().overrideLocalContent("farfalle")
                expect(resource().text) == "farfalle"
                expect(resource().latestData?.contentType) == "food/pasta"
                expect(resource().latestData?.header("Sauce-disposition")) == "garlic"
                }

            it("updates latestData’s timestamp")
                {
                setResourceTime(1000)
                stubRequest(resource, "GET").andReturn(200).withBody("hello")
                awaitNewData(resource().load())

                setResourceTime(2000)
                resource().overrideLocalContent("ahoy")

                expect(resource().latestData?.timestamp) == 2000
                expect(resource().timestamp) == 2000
                }

            it("creates new application/binary entity if latestData is nil")
                {
                resource().overrideLocalContent("fusilli")
                expect(resource().text) == "fusilli"
                expect(resource().latestData?.contentType) == "application/binary"
                }
            }

        describe("invalidate()")
            {
            let dataTimestamp  = NSTimeInterval(1000),
                errorTimestamp = NSTimeInterval(2000)

            beforeEach
                {
                setResourceTime(dataTimestamp)
                stubRequest(resource, "GET")
                awaitNewData(resource().load())
                LSNocilla.sharedInstance().clearStubs()

                setResourceTime(errorTimestamp)
                stubRequest(resource, "GET").andReturn(500)
                awaitFailure(resource().load())
                LSNocilla.sharedInstance().clearStubs()
                }

            it("does not trigger an immediate request")
                {
                resource().invalidate()
                }

            it("causes loadIfNeeded() to trigger a request")
                {
                resource().invalidate()

                stubRequest(resource, "GET")
                let req = resource().loadIfNeeded()
                expect(req).notTo(beNil())
                awaitNewData(req!)
                }

            describe("only affects loadIfNeeded() once")
                {
                beforeEach
                    { resource().invalidate() }

                afterEach
                    {
                    LSNocilla.sharedInstance().clearStubs()
                    let req = resource().loadIfNeeded()
                    expect(req).to(beNil())
                    }

                it("if loadIfNeeded() succeeds")
                    {
                    stubRequest(resource, "GET")
                    awaitNewData(resource().loadIfNeeded()!)
                    }

                it("if loadIfNeeded() fails")
                    {
                    stubRequest(resource, "GET").andReturn(500)
                    awaitFailure(resource().loadIfNeeded()!)
                    }

                it("if load() completes")
                    {
                    stubRequest(resource, "GET")
                    awaitNewData(resource().load())
                    }

                it("if local*Override() called")
                    {
                    resource().overrideLocalContent("I am a banana")
                    }
                }

            it("still affects the next loadIfNeeded() if load cancelled")
                {
                resource().invalidate()

                let reqStub = stubRequest(resource, "GET").andReturn(200).delay()
                let req = resource().load()
                req.cancel()
                reqStub.go()
                awaitFailure(req, alreadyCompleted: true)

                awaitNewData(resource().loadIfNeeded()!)
                }

            it("leaves latestData and latestError intact")
                {
                resource().invalidate()

                expect(resource().latestData).notTo(beNil())
                expect(resource().latestError).notTo(beNil())
                }

            it("leaves timestamps intact")
                {
                resource().invalidate()

                expect(resource().latestData?.timestamp) == dataTimestamp
                expect(resource().latestError?.timestamp) == errorTimestamp
                expect(resource().timestamp) == errorTimestamp
                }
            }

        describe("wipe()")
            {
            it("clears latestData")
                {
                stubRequest(resource, "GET")
                awaitNewData(resource().load())
                expect(resource().latestData).notTo(beNil())

                resource().wipe()

                expect(resource().latestData).to(beNil())
                }

            it("clears latestError")
                {
                stubRequest(resource, "GET").andReturn(500)
                awaitFailure(resource().load())
                expect(resource().latestError).notTo(beNil())

                resource().wipe()

                expect(resource().latestError).to(beNil())
                }

            it("cancels all requests in progress and prevents them from updating resource state")
                {
                let reqStubs =
                    [
                    stubRequest(resource, "GET").andReturn(200).delay(),
                    stubRequest(resource, "PUT").andReturn(200).delay(),
                    stubRequest(resource, "POST").andReturn(500).delay()
                    ]
                let reqs =
                    [
                    resource().load(),
                    resource().request(.PUT),
                    resource().request(.POST)
                    ]

                expect(resource().isLoading) == true

                resource().wipe()

                for reqStub in reqStubs
                    { reqStub.go() }
                for req in reqs
                    { awaitFailure(req, alreadyCompleted: true) }

                expect(resource().isLoading) == false
                expect(resource().latestData).to(beNil())
                expect(resource().latestError).to(beNil())
                }

            it("cancels requests attached with load(usingRequest:) even if they came from another resource")
                {
                let otherResource = resource().relative("/second_cousin_twice_removed")
                let stub = stubRequest({ otherResource }, "PUT").andReturn(200).delay()
                let otherResourceReq = otherResource.request(.PUT)
                resource().load(usingRequest: otherResourceReq)

                resource().wipe()

                stub.go()
                awaitFailure(otherResourceReq, alreadyCompleted: true)
                expect(resource().loadRequests.count) == 0
                }
            }
        }
    }


// MARK: - Helpers

private func dataAsString(data: Any?) -> String?
    {
    guard let nsdata = data as? NSData else
        { return nil }

    return NSString(data: nsdata, encoding: NSUTF8StringEncoding) as? String
    }

private class DummyObject { }
