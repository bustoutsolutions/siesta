//
//  ProgressSpec.swift
//  Siesta
//
//  Created by Paul on 2015/10/4.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

@testable import Siesta
import Quick
import Nimble
import Nocilla

class ProgressSpec: ResourceSpecBase
    {
    override func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource)
        {
        describe("always reaches 1")
            {
            it("on success")
                {
                _ = stubRequest(resource, "GET").andReturn(200)
                let req = resource().load()
                awaitNewData(req)
                expect(req.progress) == 1.0
                }

            it("on request error")
                {
                let req = resource().request(.post, text: "𐀯𐀁𐀱𐀲", encoding: String.Encoding.ascii)
                awaitFailure(req, alreadyCompleted: true)
                expect(req.progress) == 1.0
                }

            it("on server error")
                {
                _ = stubRequest(resource, "GET").andReturn(500)
                let req = resource().load()
                awaitFailure(req)
                expect(req.progress) == 1.0
                }

            it("on connection error")
                {
                _ = stubRequest(resource, "GET").andFailWithError(NSError(domain: "foo", code: 1, userInfo: nil))
                let req = resource().load()
                awaitFailure(req)
                expect(req.progress) == 1.0
                }

            it("on cancellation")
                {
                let reqStub = stubRequest(resource, "GET").andReturn(200).delay()
                let req = resource().load()
                req.cancel()
                expect(req.progress) == 1.0
                _ = reqStub.go()
                awaitFailure(req, alreadyCompleted: true)
                }
            }

        // Exact progress values are subjective, and subject to change. These specs only examine
        // what affects the progress computation.

        describe("computation")
            {
            var getRequest: Bool!
            var metrics: RequestTransferMetrics!
            var progress: RequestProgressComputation?

            beforeEach
                {
                progress = nil
                metrics = RequestTransferMetrics(
                    requestBytesSent: 0,
                    requestBytesTotal: nil,
                    responseBytesReceived: 0,
                    responseBytesTotal: nil)
                setResourceTime(100)
                }

            func progressComparison(_ closure: (Void) -> Void) -> (before: Double, after: Double)
                {
                progress = progress ?? RequestProgressComputation(isGet: getRequest)

                progress!.update(from: metrics)
                let before = progress!.fractionDone

                closure()

                progress!.update(from: metrics)
                let after = progress!.fractionDone

                return (before, after)
                }

            func expectProgressToIncrease(_ closure: (Void) -> Void)
                {
                let result = progressComparison(closure)
                expect(result.after) > result.before
                }

            func expectProgressToRemainUnchanged(_ closure: (Void) -> Void)
                {
                let result = progressComparison(closure)
                expect(result.after) == result.before
                }

            func expectProgressToRemainAlmostUnchanged(_ closure: (Void) -> Void)
                {
                let result = progressComparison(closure)
                expect(result.after) ≈ result.before ± 0.01
                }

            context("for request with no body")
                {
                beforeEach { getRequest = true }

                it("increases while waiting for request to start")
                    {
                    expectProgressToIncrease
                        { setResourceTime(101) }
                    }

                it("is stable when response arrives")
                    {
                    expectProgressToIncrease { setResourceTime(101) }
                    expectProgressToRemainAlmostUnchanged
                        {
                        setResourceTime(1000)
                        metrics.responseBytesReceived = 1
                        metrics.responseBytesTotal = 1000
                        }
                    }

                it("tracks download")
                    {
                    metrics.requestBytesSent = 0
                    metrics.requestBytesTotal = 0
                    metrics.responseBytesReceived = 1
                    metrics.responseBytesTotal = 1000
                    expectProgressToIncrease
                        { metrics.responseBytesReceived = 2 }
                    }

                it("tracks download even when size is unknown")
                    {
                    metrics.requestBytesSent = 0
                    metrics.requestBytesTotal = 0
                    metrics.responseBytesReceived = 1
                    expectProgressToIncrease
                        { metrics.responseBytesReceived = 2 }
                    }

                it("never reaches 1 if response size is unknown")
                    {
                    metrics.requestBytesSent = 0
                    metrics.requestBytesTotal = 0
                    metrics.responseBytesReceived = 1
                    metrics.responseBytesTotal = -1
                    expectProgressToIncrease
                        { metrics.responseBytesReceived = 1000000 }
                    expect(progress?.rawFractionDone) < 1
                    }

                it("is stable when estimated download size becomes precise")
                    {
                    metrics.requestBytesSent = 0
                    metrics.requestBytesTotal = 0
                    metrics.responseBytesReceived = 10
                    expectProgressToRemainUnchanged
                        { metrics.responseBytesTotal = 20 }
                    }

                it("does not exceed 1 even if bytes downloaded exceed total")
                    {
                    metrics.responseBytesReceived = 10000
                    metrics.responseBytesTotal = 2
                    expectProgressToRemainUnchanged
                        { metrics.responseBytesReceived = 20000 }
                    expect(progress?.rawFractionDone) == 1
                    }
                }

            context("for request with a body")
                {
                beforeEach { getRequest = false }

                it("is stable when request starts uploading after a delay")
                    {
                    expectProgressToIncrease { setResourceTime(101) }
                    expectProgressToRemainAlmostUnchanged
                        {
                        setResourceTime(1000)
                        metrics.requestBytesSent = 1
                        metrics.requestBytesTotal = 1000
                        }
                    }

                it("tracks upload")
                    {
                    metrics.requestBytesSent = 1
                    metrics.requestBytesTotal = 1000
                    expectProgressToIncrease
                        { metrics.requestBytesSent = 2 }
                    }

                it("tracks upload even if upload size is unknown")
                    {
                    metrics.requestBytesSent = 10
                    metrics.requestBytesTotal = -1
                    expectProgressToIncrease
                        { metrics.requestBytesSent = 11 }
                    }

                it("is stable when estimated upload size becomes precise")
                    {
                    metrics.requestBytesSent = 10
                    metrics.requestBytesTotal = -1
                    expectProgressToRemainUnchanged
                        { metrics.requestBytesTotal = 100 }
                    }

                it("does not track time while uploading")
                    {
                    metrics.requestBytesSent = 1
                    metrics.requestBytesTotal = 1000
                    expectProgressToRemainUnchanged
                        { setResourceTime(120) }
                    }

                it("increases while waiting for response after upload")
                    {
                    metrics.requestBytesSent = 1000
                    metrics.requestBytesTotal = 1000
                    expectProgressToIncrease
                        { setResourceTime(110) }
                    }

                it("is stable when response arrives")
                    {
                    metrics.requestBytesSent = 1000
                    metrics.requestBytesTotal = 1000
                    expectProgressToIncrease { setResourceTime(110) }
                    expectProgressToRemainAlmostUnchanged
                        {
                        setResourceTime(110)
                        metrics.responseBytesReceived = 1
                        metrics.responseBytesTotal = 1000
                        }
                    }

                it("tracks download")
                    {
                    metrics.requestBytesSent = 1000
                    metrics.requestBytesTotal = 1000
                    metrics.responseBytesReceived = 1
                    metrics.responseBytesTotal = 1000
                    expectProgressToIncrease
                        { metrics.responseBytesReceived = 2 }
                    }
                }
            }

        describe("callback")
            {
            @discardableResult
            func recordProgress(
                    setup: (Request) -> Void = { _ in },
                    until stopCondition: @escaping ([Double]) -> Bool)
                -> [Double]
                {
                var progressReports: [Double] = []

                let expectation = QuickSpec.current().expectation(description: "recordProgressUntil")
                var fulfilled = false

                let reqStub = stubRequest(resource, "GET").andReturn(200).delay()
                let req = resource().load().onProgress
                    {
                    progressReports.append($0)
                    if !fulfilled && stopCondition(progressReports)
                        {
                        fulfilled = true
                        expectation.fulfill()
                        }
                    }
                setup(req)
                QuickSpec.current().waitForExpectations(timeout: 1, handler: nil)

                _ = reqStub.go()
                awaitNewData(req)

                return progressReports
                }

            it("receives periodic updates during request")
                {
                let progressReports = recordProgress(until: { $0.count >= 4 })

                // The mere passage of time should increase latency, and thus make progress increase beyond 0
                expect(progressReports.any { $0 > 0 }) == true
                expect(progressReports.sorted()) == progressReports
                }

            describe("last notification")
                {
                it("is 1")
                    {
                    let progressReports = recordProgress(until: { _ in true })
                    expect(progressReports.last) == 1
                    }

                it("comes before the completion callback")
                    {
                    var completionCalled = false
                    recordProgress(
                        setup:
                            {
                            $0.onProgress { _ in expect(completionCalled) == false }
                              .onCompletion { _ in completionCalled = true }
                            },
                        until: { _ in true })
                    }
                }
            }
        }
    }
