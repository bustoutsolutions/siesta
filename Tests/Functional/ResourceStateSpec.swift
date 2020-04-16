//
//  ResourceStateSpec.swift
//  Siesta
//
//  Created by Paul on 2015/7/5.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta

import Foundation
import Quick
import Nimble

class ResourceStateSpec: ResourceSpecBase
    {
    override func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource)
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
            it("does not update the resource state")
                {
                NetworkStub.add(.get, resource)
                awaitNewData(resource().request(.get))
                expect(resource().latestData).to(beNil())
                expect(resource().latestError).to(beNil())
                }

            // TODO: How to reproduce these conditions in tests?
            pending("server response has no effect if it arrives but cancel() already called") { }
            pending("cancel() has no effect after request completed") { }

            it("tracks concurrent requests")
                {
                @discardableResult
                func stubDelayedAndRequest(_ ident: String) -> (RequestStub, Request)
                    {
                    let reqStub =
                        NetworkStub.add(
                            matching: RequestPattern(
                                .get, resource,
                                headers: ["Request-ident": ident]))
                        .delay()
                    let req = resource().request(.get)
                        { $0.setValue(ident, forHTTPHeaderField: "Request-ident") }
                    return (reqStub, req)
                    }

                let (reqStub0, req0) = stubDelayedAndRequest("zero"),
                    (reqStub1, req1) = stubDelayedAndRequest("one")

                expect(resource().isRequesting) == true
                expect(resource().allRequests).to(beIdentialObjects([req0, req1]))

                _ = reqStub0.go()
                awaitNewData(req0)
                expect(resource().isRequesting) == true
                expect(resource().allRequests).to(beIdentialObjects([req1]))

                _ = reqStub1.go()
                awaitNewData(req1)
                expect(resource().isLoading) == false
                expect(resource().allRequests).to(beIdentialObjects([]))
                }
            }

        describe("load()")
            {
            it("marks that the resource is loading")
                {
                expect(resource().isLoading) == false

                NetworkStub.add(.get, resource)
                let req = resource().load()
                expect(resource().isLoading) == true

                awaitNewData(req)
                expect(resource().isLoading) == false
                }

            it("stores the response data")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(body: "eep eep"))
                awaitNewData(resource().load())

                expect(resource().latestData).notTo(beNil())
                expect(dataAsString(resource().latestData?.content)) == "eep eep"
                }

            it("stores the content type")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(headers: ["cOnTeNt-TyPe": "text/monkey"]))
                awaitNewData(resource().load())

                expect(resource().latestData?.contentType) == "text/monkey"
                }

            it("extracts the charset if present")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(headers: ["Content-type": "text/monkey; charset=utf-8"]))
                awaitNewData(resource().load())

                expect(resource().latestData?.charset) == "utf-8"
                }

            it("includes the charset in the content type")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(headers: ["Content-type": "text/monkey; charset=utf-8"]))
                awaitNewData(resource().load())

                expect(resource().latestData?.contentType) == "text/monkey; charset=utf-8"
                }

            it("parses the charset")
                {
                let monkeyType = "text/monkey; body=fuzzy; charset=euc-jp; arms=long"
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(headers: ["Content-type": monkeyType]))
                awaitNewData(resource().load())

                expect(resource().latestData?.contentType) == monkeyType
                expect(resource().latestData?.charset) == "euc-jp"
                }

            it("defaults content type to raw binary")
                {
                NetworkStub.add(.get, resource)
                awaitNewData(resource().load())

                // Although Apple's URLResponse.contentType defaults to text/plain,
                // the correct default content type for HTTP is application/octet-stream.
                // http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.2.1

                expect(resource().latestData?.contentType) == "application/octet-stream"
                }

            it("stores headers")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(headers: ["Personal-Disposition": "Quirky"]))
                awaitNewData(resource().load())

                expect(resource().latestData?.header(forKey: "Personal-Disposition")) == "Quirky"
                expect(resource().latestData?.header(forKey: "pErsonal-dIsposition")) == "Quirky"
                expect(resource().latestData?.header(forKey: "pErsonaldIsposition")).to(beNil())
                }

            it("handles missing etag")
                {
                NetworkStub.add(.get, resource)
                awaitNewData(resource().load())

                expect(resource().latestData?.etag).to(beNil())
                }

            func sendAndWaitForSuccessfulRequest()
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(
                        headers:
                            [
                            "eTaG": "123 456 xyz",
                            "Content-Type": "applicaiton/zoogle+plotz"
                            ],
                        body: "zoogleplotz"))

                awaitNewData(resource().load())
                NetworkStub.clearAll()
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
                    NetworkStub.add(
                        matching: RequestPattern(
                            .get, resource,
                            headers: ["If-None-Match": "123 456 xyz"]),
                        returning: HTTPResponse(status: 304))
                    awaitNotModified(resource().load())
                    }

                it("handles subsequent 200 by replacing data")
                    {
                    NetworkStub.add(
                        .get, resource,
                        returning: HTTPResponse(
                            headers:
                                [
                                "eTaG": "ABC DEF 789",
                                "Content-Type": "applicaiton/ploogle+zotz"
                                ],
                            body: "plooglezotz"))
                    awaitNewData(resource().load())

                    expect(dataAsString(resource().latestData?.content)) == "plooglezotz"
                    expect(resource().latestData?.contentType) == "applicaiton/ploogle+zotz"
                    expect(resource().latestData?.etag) == "ABC DEF 789"
                    }

                it("handles subsequent 304 by keeping existing data")
                    {
                    NetworkStub.add(.get, resource, status: 304)
                    awaitNotModified(resource().load())

                    expectDataToBeUnchanged()
                    expect(resource().latestError).to(beNil())
                    }
                }

            func stubError(_ error: Error)
                {
                NetworkStub.add(
                    .get, resource,
                    returning: ErrorResponse(
                        error: error))
                }

            it("handles request errors")
                {
                stubError(NSError(domain: "TestDomain", code: 12345, userInfo: nil))
                awaitFailure(resource().load())

                expect(resource().latestData).to(beNil())
                expect(resource().latestError).notTo(beNil())
                let nserror = resource().latestError?.cause?.unwrapAlamofireError as NSError?
                expect(nserror?.domain) == "TestDomain"
                expect(nserror?.code) == 12345
                }

            // Testing all these HTTP codes individually because Apple likes
            // to treat specific ones as special cases.

            for statusCode in Array(400...410) + (500...505)
                {
                it("treats HTTP \(statusCode) as an error")
                    {
                    NetworkStub.add(.get, resource, status: statusCode)
                    awaitFailure(resource().load())

                    expect(resource().latestData).to(beNil())
                    expect(resource().latestError).notTo(beNil())
                    expect(resource().latestError?.httpStatusCode) == statusCode
                    }
                }

            it("preserves last valid data after error")
                {
                sendAndWaitForSuccessfulRequest()

                NetworkStub.add(.get, resource, status: 500)
                awaitFailure(resource().load())

                expectDataToBeUnchanged()
                }

            it("leaves everything unchanged after a cancelled request")
                {
                sendAndWaitForSuccessfulRequest()

                let reqStub = NetworkStub.add(.get, resource).delay()
                let req = resource().load()
                req.cancel()
                _ = reqStub.go()
                awaitFailure(req, initialState: .completed)

                expectDataToBeUnchanged()
                expect(resource().latestError).to(beNil())
                }

            // TODO: test no internet connnection if possible

            it("generates error messages from NSError message")
                {
                stubError(NSError(
                    domain: "TestDomain", code: 12345,
                    userInfo: [NSLocalizedDescriptionKey: "KABOOM"]))
                awaitFailure(resource().load())

                expect(resource().latestError?.userMessage)
                    .to(match("^(URLSessionTask failed with error: )?KABOOM$")) // Alamofire adds this prefix 😒
                }

            it("generates error messages from HTTP status codes")
                {
                NetworkStub.add(.get, resource, status: 404)
                awaitFailure(resource().load())

                expect(resource().latestError?.userMessage) == "Not found"
                }

            // TODO: how should it handle redirects?
            }

        describe("loadIfNeeded()")
            {
            func expectToLoad(_ reqClosure: @autoclosure () -> Request?, returning loadReq: Request? = nil)
                {
                NetworkStub.add(.get, resource) // Stub first...
                let reqReturned = reqClosure()                  // ...then allow loading
                expect(resource().isLoading) == true
                expect(reqReturned).notTo(beNil())
                if loadReq != nil
                    { expect(reqReturned) === loadReq }
                if let reqReturned = reqReturned
                    { awaitNewData(reqReturned) }
                }

            func expectNotToLoad(_ req: Request?)
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
                NetworkStub.add(.get, resource)
                let existingReq = resource().load()
                expectToLoad(resource().loadIfNeeded(), returning: existingReq)
                }

            it("initiates a new request if a non-load request is in progress")
                {
                let postReqStub = NetworkStub.add(.post, resource).delay(),
                    loadReqStub = NetworkStub.add(.get, resource).delay()
                let postReq = resource().request(.post),
                    loadReq = resource().loadIfNeeded()

                expect(loadReq).toNot(beNil())

                _ = postReqStub.go()
                awaitNewData(postReq)
                _ = loadReqStub.go()
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
                    service().configure("**") { $0.expirationTime = 1 }
                    setResourceTime(1002)
                    expectToLoad(resource().loadIfNeeded())
                    }
                }

            context("with an error present")
                {
                beforeEach
                    {
                    setResourceTime(1000)
                    NetworkStub.add(.get, resource, status: 404)
                    awaitFailure(resource().load())
                    NetworkStub.clearAll()
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
                    service().configure("**") { $0.retryTime = 1 }
                    setResourceTime(1002)
                    expectToLoad(resource().loadIfNeeded())
                    }
                }
            }

        describe("load(using:)")
            {
            let request = specVar { resource().request(.post) }

            beforeEach
                {
                NetworkStub.add(
                    .post, resource,
                    returning: HTTPResponse(
                        headers: ["Content-type": "text/plain"],
                        body: "Posted!"))
                }

            it("updates resource state")
                {
                awaitNewData(resource().load(using: request()))
                expect(resource().text) == "Posted!"
                }

            it("notifies observers")
                {
                var observerNotified = false
                resource().addObserver(owner: request())
                    { _,_  in observerNotified = true }

                resource().load(using: request())

                awaitNewData(request())
                expect(observerNotified) == true

                resource().removeObservers(ownedBy: request())
                }
            }

        describe("cancelLoadIfUnobserved()")
            {
            let reqStub = specVar { NetworkStub.add(.get, resource).delay() }
            let req = specVar { resource().load() }
            var owner: AnyObject?

            beforeEach
                {
                _ = reqStub()
                _ = req()
                owner = DummyObject()
                resource().addObserver(owner: owner!) { _,_ in }
                owner = DummyObject() // replaces old one
                // Resource now has outstanding load request & no observers
                }

            afterEach
                { owner = nil }

            it("cancels if resource has no observers")
                {
                resource().cancelLoadIfUnobserved()

                _ = reqStub().go()
                awaitFailure(req(), initialState: .completed)
                }

            it("does not cancel if resource has an observer")
                {
                resource().addObserver(owner: owner!) { _,_ in }
                resource().cancelLoadIfUnobserved()

                _ = reqStub().go()
                awaitNewData(req())
                }

            it("cancels multiple load requests")
                {
                let req0 = resource().load(),
                    req1 = resource().load()

                resource().cancelLoadIfUnobserved()

                _ = reqStub().go()
                awaitFailure(req0, initialState: .completed)
                awaitFailure(req1, initialState: .completed)
                }

            describe("(afterDelay:)")
                {
                it("cancels load if resource loses its observers during delay")
                    {
                    let expectation = QuickSpec.current.expectation(description: "cancelLoadIfUnobserved(afterDelay:")
                    resource().addObserver(owner: owner!) { _,_ in }
                    resource().cancelLoadIfUnobserved(afterDelay: 0.001)
                        { expectation.fulfill() }
                    owner = nil
                    QuickSpec.current.waitForExpectations(timeout: 1)

                    _ = reqStub().go()
                    awaitFailure(req(), initialState: .completed)
                    }

                it("does not cancel load if resource gains an observer during delay")
                    {
                    let expectation = QuickSpec.current.expectation(description: "cancelLoadIfUnobserved(afterDelay:")
                    resource().cancelLoadIfUnobserved(afterDelay: 0.001)
                        { expectation.fulfill() }
                    resource().addObserver(owner: owner!) { _,_ in }
                    QuickSpec.current.waitForExpectations(timeout: 1)

                    _ = reqStub().go()
                    awaitNewData(req())
                    }

                it("cancels load after the delay")
                    {
                    let expectation = QuickSpec.current.expectation(description: "cancelLoadIfUnobserved(afterDelay:)")
                    resource().cancelLoadIfUnobserved(afterDelay: 0.2)
                        { expectation.fulfill() }
                    QuickSpec.current.waitForExpectations(timeout: 1.0)

                    _ = reqStub().go()
                    awaitFailure(req(), initialState: .completed)
                    }

                it("does not cancel load before the delay")
                    {
                    let expectation = QuickSpec.current.expectation(description: "cancelLoadIfUnobserved(afterDelay:)")
                    expectation.isInverted = true
                    resource().cancelLoadIfUnobserved(afterDelay: 0.3)
                        { expectation.fulfill() }
                    QuickSpec.current.waitForExpectations(timeout: 0.05)

                    _ = reqStub().go()
                    awaitNewData(req())
                    }
                }
            }

        describe("overrideLocalData()")
            {
            let arbitraryContentType = "content-can-be/anything"
            let arbitraryContent = specVar { NSCalendar(identifier: NSCalendar.Identifier.ethiopicAmeteMihret) as AnyObject }
            let localData = specVar { Entity<Any>(content: arbitraryContent(), contentType: arbitraryContentType) }

            it("updates the data")
                {
                resource().overrideLocalData(with: localData())
                expect(resource().latestData?.content) === arbitraryContent()
                expect(resource().latestData?.contentType) == arbitraryContentType
                }

            it("clears the latest error")
                {
                NetworkStub.add(.get, resource, status: 500)
                awaitFailure(resource().load())
                expect(resource().latestError).notTo(beNil())

                resource().overrideLocalData(with: localData())
                expect(resource().latestData).notTo(beNil())
                expect(resource().latestError).to(beNil())
                }

            it("does not touch the transformer pipeline")
                {
                let rawData = DummyObject()
                resource().overrideLocalData(with: Entity<Any>(content: rawData, contentType: "text/plain"))
                expect(resource().latestData?.content as? DummyObject) === rawData
                }
            }

        describe("overrideLocalContent()")
            {
            it("updates latestData’s content without altering headers")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(
                        headers:
                            [
                            "Content-type": "food/pasta",
                            "Sauce-disposition": "garlic"
                            ],
                        body: "linguine"))

                awaitNewData(resource().load())

                resource().overrideLocalContent(with: "farfalle")
                expect(resource().text) == "farfalle"
                expect(resource().latestData?.contentType) == "food/pasta"
                expect(resource().latestData?.header(forKey: "Sauce-disposition")) == "garlic"
                }

            it("updates latestData’s timestamp")
                {
                setResourceTime(1000)
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(body: "hello"))
                awaitNewData(resource().load())

                setResourceTime(2000)
                resource().overrideLocalContent(with: "ahoy")

                expect(resource().latestData?.timestamp) == 2000
                expect(resource().timestamp) == 2000
                }

            it("creates new application/binary entity if latestData is nil")
                {
                resource().overrideLocalContent(with: "fusilli")
                expect(resource().text) == "fusilli"
                expect(resource().latestData?.contentType) == "application/binary"
                }
            }

        describe("invalidate()")
            {
            let dataTimestamp  = TimeInterval(1000),
                errorTimestamp = TimeInterval(2000)

            beforeEach
                {
                setResourceTime(dataTimestamp)
                NetworkStub.add(.get, resource)
                awaitNewData(resource().load())
                NetworkStub.clearAll()

                setResourceTime(errorTimestamp)
                NetworkStub.add(.get, resource, status: 500)
                awaitFailure(resource().load())
                NetworkStub.clearAll()
                }

            it("does not trigger an immediate request")
                {
                resource().invalidate()
                }

            it("causes loadIfNeeded() to trigger a request")
                {
                resource().invalidate()

                NetworkStub.add(.get, resource)
                let req = resource().loadIfNeeded()
                expect(req).notTo(beNil())
                awaitNewData(req!)
                }

            context("only affects loadIfNeeded() once")
                {
                beforeEach
                    { resource().invalidate() }

                afterEach
                    {
                    NetworkStub.clearAll()
                    let req = resource().loadIfNeeded()
                    expect(req).to(beNil())
                    }

                it("if loadIfNeeded() succeeds")
                    {
                    NetworkStub.add(.get, resource)
                    awaitNewData(resource().loadIfNeeded()!)
                    }

                it("if loadIfNeeded() fails")
                    {
                    NetworkStub.add(.get, resource, status: 500)
                    awaitFailure(resource().loadIfNeeded()!)
                    }

                it("if load() completes")
                    {
                    NetworkStub.add(.get, resource)
                    awaitNewData(resource().load())
                    }

                it("if local*Override() called")
                    {
                    resource().overrideLocalContent(with: "I am a banana")
                    }
                }

            it("still affects the next loadIfNeeded() if load cancelled")
                {
                resource().invalidate()

                let reqStub = NetworkStub.add(.get, resource).delay()
                let req = resource().load()
                req.cancel()
                _ = reqStub.go()
                awaitFailure(req, initialState: .completed)

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
                NetworkStub.add(.get, resource)
                awaitNewData(resource().load())
                expect(resource().latestData).notTo(beNil())

                resource().wipe()

                expect(resource().latestData).to(beNil())
                }

            it("clears latestError")
                {
                NetworkStub.add(.get, resource, status: 500)
                awaitFailure(resource().load())
                expect(resource().latestError).notTo(beNil())

                resource().wipe()

                expect(resource().latestError).to(beNil())
                }

            it("cancels all requests in progress and prevents them from updating resource state")
                {
                let reqStubs =
                    [
                    NetworkStub.add(.get,  resource).delay(),
                    NetworkStub.add(.put,  resource).delay(),
                    NetworkStub.add(.post, resource).delay()
                    ]
                let reqs =
                    [
                    resource().load(),
                    resource().request(.put),
                    resource().request(.post)
                    ]

                expect(resource().isLoading) == true

                resource().wipe()

                for reqStub in reqStubs
                    { _ = reqStub.go() }
                for req in reqs
                    { awaitFailure(req, initialState: .completed) }

                expect(resource().isLoading) == false
                expect(resource().latestData).to(beNil())
                expect(resource().latestError).to(beNil())
                }

            it("cancels requests attached with load(using:) even if they came from another resource")
                {
                let otherResource = resource().relative("/second_cousin_twice_removed")
                let stub = NetworkStub.add(.put, { otherResource }).delay()
                let otherResourceReq = otherResource.request(.put)
                resource().load(using: otherResourceReq)

                resource().wipe()

                _ = stub.go()
                awaitFailure(otherResourceReq, initialState: .completed)
                expect(resource().loadRequests.count) == 0
                }
            }
        }
    }


// MARK: - Helpers

private func dataAsString(_ data: Any?) -> String?
    {
    guard let nsdata = data as? Data else
        { return nil }

    return String(data: nsdata, encoding: String.Encoding.utf8)
    }

private class DummyObject { }
