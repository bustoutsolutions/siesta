//
//  RxSwiftSpec.swift
//  Siesta
//
//  Created by Adrian on 2020/4/15.
//  Copyright © 2020 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble
import RxSwift

class RxSwiftSpec: ResourceSpecBase
    {
    override func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource)
        {
        describe("Resource.rx.state()")
            {
            it("outputs content when the request succeeds")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "pee hoo"))

                let loadingExpectation = QuickSpec.current.expectation(description: "isLoading set")
                let requestingExpectation = QuickSpec.current.expectation(description: "isRequesting set")
                let newDataEventExpectation = QuickSpec.current.expectation(description: "awaiting newData event")

                resource().rx.state()
                        .subscribeUntilTested
                            {
                            (state: ResourceState<String>) in
                            expect(state.latestError).to(beNil())
                            if state.isLoading { loadingExpectation.fulfill() }
                            if state.isRequesting { requestingExpectation.fulfill() }
                            if case .newData = state.latestEvent { newDataEventExpectation.fulfill() }

                            if let content = state.content
                                {
                                expect(content) == "pee hoo"
                                return true
                                }
                            return false
                            }
                }

            it("outputs content when the content is already cached")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "pee hoo"))

                let observableExpectation = QuickSpec.current.expectation(description: "awaiting observable")
                resource().rx.state()
                    .compactMap
						{
						(state: ResourceState<String>) in
                        state.content != nil ? resource().rx.state() : nil
                    	}
                    .take(1)
                    .switchLatest()
                    .subscribeUntilTested
						{
						(state: ResourceState<String>) in
                        if let s = state.content
							{
                            expect(s) == "pee hoo"
                            observableExpectation.fulfill()
                            return true
                        	}
                        return false
                    	}
                }

            it("outputs content again when it changes")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "pee hoo"))

                let observableExpectation = QuickSpec.current.expectation(description: "awaiting observable")

                _ = resource().rx.state()
                        .do(onNext: { expect($0.latestError).to(beNil()) })
                        .compactMap { $0.content as String? }
                        .do(onNext:
                            {
                            _ in
                            NetworkStub.add(
                                .get, resource,
                                returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "whoo baa"))

                            resource().load()
                            })
                        .distinctUntilChanged()
                        .take(2)
                        .toArray()
                        .subscribe(onSuccess:
                            {
                            expect($0) == ["pee hoo", "whoo baa"]
                            observableExpectation.fulfill()
                            })

                QuickSpec.current.waitForExpectations(timeout: 1)
                }

            it("outputs an error when the request fails")
                {
                NetworkStub.add(.get, resource, status: 404)

                resource().rx.state()
                        .subscribeUntilTested
                            {
                            (state: ResourceState<String>) in
                            if state.latestError != nil
                                { return true }
                            return false
                            }
                }

            it("outputs an error if the content type is wrong")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(headers: ["Content-Type": "application/json"], body: "{}"))

                resource().rx.state()
                        .subscribeUntilTested
                            {
                            (state: ResourceState<String>) in
                            if let error = state.latestError
                                {
                                expect(error.cause).to(beAKindOf(RequestError.Cause.WrongContentType.self))
                                return true
                                }
                            return false
                            }
                }
            }


        describe("Resource.rx.content()")
            {
            it("outputs content changes")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "pee hoo"))

                let observableExpectation = QuickSpec.current.expectation(description: "awaiting observable")

                _ = resource().rx.content()
                        .do(onNext:
                            {
                            (_: String) in
                            NetworkStub.add(
                                .get, resource,
                                returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "whoo baa"))

                            resource().load()
                            })
                        .distinctUntilChanged()
                        .take(2)
                        .toArray()
                        .subscribe(onSuccess:
                            {
                            expect($0) == ["pee hoo", "whoo baa"]
                            observableExpectation.fulfill()
                            })

                QuickSpec.current.waitForExpectations(timeout: 1)
                }

            it("outputs content when the content is already cached")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "pee hoo"))

                let observableExpectation = QuickSpec.current.expectation(description: "awaiting observable")
                _ = resource().rx.content()
                    .take(1)
                    .map { (_: String) in resource().rx.content() }
                    .switchLatest()
                    .take(1)
                    .subscribe(onNext:
                    {
                        (s: String) in
                        expect(s) == "pee hoo"
                        observableExpectation.fulfill()
                    })

                QuickSpec.current.waitForExpectations(timeout: 1)
                }
            }


        // ------------ Resource.rx.request* ------------

        describe("Resource.rx.request()")
            {
            it("outputs content then completes")
                {
                NetworkStub.add(
                    .put, resource,
                    returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "ree sult"))

                let outputExpectation = QuickSpec.current.expectation(description: "awaiting completion")
                let completionExpectation = QuickSpec.current.expectation(description: "awaiting completion")

                _ = resource().rx.request { $0.request(.put) }
                        .subscribe(
                                onNext: { (result: String) in
                                    expect(result) == "ree sult"
                                    outputExpectation.fulfill()
                                },
                                onCompleted: { completionExpectation.fulfill() }
                        )

                QuickSpec.current.waitForExpectations(timeout: 1)
                }

            it("fails when the request fails")
                {
                NetworkStub.add(.put, resource, status: 500)

                let expectation = QuickSpec.current.expectation(description: "awaiting error")

                _ = resource().rx.request { $0.request(.put) }
                        .subscribe(
                                onNext: { (_: String) in },
                                onError: { _ in expectation.fulfill() }
                        )

                QuickSpec.current.waitForExpectations(timeout: 1)
                }
            }


        describe("Resource.rx.requestSingle()")
            {
            it("outputs content")
                {
                NetworkStub.add(
                    .put, resource,
                    returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "ree sult"))

                let expectation = QuickSpec.current.expectation(description: "awaiting completion")

                _ = resource().rx.requestSingle { $0.request(.put) }
                        .subscribe(onSuccess: { (result: String) in
                            expect(result) == "ree sult"
                            expectation.fulfill()
                        })

                QuickSpec.current.waitForExpectations(timeout: 1)
                }

            it("fails when the request fails")
                {
                NetworkStub.add(.put, resource, status: 500)

                let expectation = QuickSpec.current.expectation(description: "awaiting error")

                _ = resource().rx.requestSingle { $0.request(.put) }
                        .subscribe(
                                onSuccess: { (_: String) in },
                                onError: { _ in expectation.fulfill() }
                        )

                QuickSpec.current.waitForExpectations(timeout: 1)
                }
            }


        describe("Resource.rx.requestCompletable()")
            {
            it("completes when the request succeeds")
                {
                NetworkStub.add(.put, resource, status: 200)

                let expectation = QuickSpec.current.expectation(description: "awaiting completion")

                _ = resource().rx.requestCompletable { $0.request(.put) }
                        .subscribe(onCompleted: { expectation.fulfill() })

                QuickSpec.current.waitForExpectations(timeout: 1)
                }

            it("fails when the request fails")
                {
                NetworkStub.add(.put, resource, status: 500)

                let expectation = QuickSpec.current.expectation(description: "awaiting error")

                _ = resource().rx.requestCompletable { $0.request(.put) }
                        .subscribe(onError: { _ in expectation.fulfill() })

                QuickSpec.current.waitForExpectations(timeout: 1)
                }
            }


        describe("Resource.rx.requestSingle()")
            {
            it("outputs content when the request succeeds")
                {
                NetworkStub.add(
                    .put, resource,
                    returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "whoo baa"))

                let expectation = QuickSpec.current.expectation(description: "awaiting completion")

                _ = resource().rx.requestSingle { $0.request(.put) }
                        .subscribe(onSuccess:
                            {
                            (s: String) in
                            expect(s) == "whoo baa"
                            expectation.fulfill()
                            })

                QuickSpec.current.waitForExpectations(timeout: 1)
                }

            it("fails when the request fails")
                {
                NetworkStub.add(.put, resource, status: 500)

                let expectation = QuickSpec.current.expectation(description: "awaiting error")

                _ = resource().rx.requestSingle { $0.request(.put) }
                        .subscribe(
                                onSuccess: { (_: String) in },
                                onError: { _ in expectation.fulfill() }
                        )

                QuickSpec.current.waitForExpectations(timeout: 1)
                }
            }


        // ------------ Request.rx.* ------------

        describe("Request.rx.observable()")
            {
            it("outputs content then completes")
                {
                NetworkStub.add(
                    .put, resource,
                    returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "ree sult"))

                let outputExpectation = QuickSpec.current.expectation(description: "awaiting completion")
                let completionExpectation = QuickSpec.current.expectation(description: "awaiting completion")

                _ = resource().request(.put).rx.observable().subscribe(
                        onNext: { (result: String) in
                            expect(result) == "ree sult"
                            outputExpectation.fulfill()
                        },
                        onCompleted: { completionExpectation.fulfill() }
                    )

                QuickSpec.current.waitForExpectations(timeout: 1)
                }

            it("fails when the request fails")
                {
                NetworkStub.add(.put, resource, status: 500)

                let expectation = QuickSpec.current.expectation(description: "awaiting error")

                _ = resource().request(.put).rx.observable().subscribe(
                        onNext: { (_: String) in },
                        onError: { _ in expectation.fulfill() }
                    )

                QuickSpec.current.waitForExpectations(timeout: 1)
                }
            }

        describe("Request.rx.completable()")
            {
            it("completes when the request succeeds")
                {
                NetworkStub.add(.put, resource, status: 200)

                let expectation = QuickSpec.current.expectation(description: "awaiting completion")

                _ = resource()
                    .request(.put).rx.completable().subscribe(
                        onCompleted: { expectation.fulfill() }
                    )

                QuickSpec.current.waitForExpectations(timeout: 1)
                }

            it("fails when the request fails")
                {
                NetworkStub.add(.put, resource, status: 500)

                let expectation = QuickSpec.current.expectation(description: "awaiting error")

                _ = resource()
                    .request(.put).rx.completable().subscribe(
                        onError: { _ in expectation.fulfill() }
                    )

                QuickSpec.current.waitForExpectations(timeout: 1)
                }
        }

        describe("Request.rx.single()") {
            it("outputs content when the request succeeds")
                {
                NetworkStub.add(
                    .put, resource,
                    returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "whoo baa"))

                let expectation = QuickSpec.current.expectation(description: "awaiting completion")

                _ = resource()
                    .request(.put).rx.single().subscribe(
                        onSuccess: { (s: String) in
                            expect(s) == "whoo baa"
                            expectation.fulfill()
                        })

                QuickSpec.current.waitForExpectations(timeout: 1)
                }

            it("fails when the request fails")
                {
                NetworkStub.add(.put, resource, status: 500)

                let expectation = QuickSpec.current.expectation(description: "awaiting error")

                _ = resource().request(.put).rx.single().subscribe(
                        onSuccess: { (_: String) in },
                        onError: { _ in expectation.fulfill() }
                    )

                QuickSpec.current.waitForExpectations(timeout: 1)
                }
            }
        }
    }

extension Observable
    {
    fileprivate func subscribeUntilTested(testNext: @escaping (Element) -> Bool)
        {
        let observableExpectation = QuickSpec.current.expectation(description: "awaiting observable")

        _ = takeUntil(.inclusive) { elt in
            var res: Bool?
            let fe = gatherFailingExpectations { res = testNext(elt) }
            return res! || !fe.isEmpty
            }
            .subscribe(onDisposed: { observableExpectation.fulfill() })

        QuickSpec.current.waitForExpectations(timeout: 1)
        }
    }
