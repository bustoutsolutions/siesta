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
import Nocilla
import RxSwift

// todo add to macOS and tvOS

class RxSwiftSpec: ResourceSpecBase
    {
    override func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource)
        {
        describe("state()")
            {
            it("outputs content when the request succeeds")
                {
                _ = stubRequest(resource, "GET")
                        .andReturn(200)
                        .withHeader("Content-type", "text/plain")
                        .withBody("pee hoo" as NSString)

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

            it("outputs content again when it changes")
                {
                _ = stubRequest(resource, "GET")
                        .andReturn(200)
                        .withHeader("Content-type", "text/plain")
                        .withBody("pee hoo" as NSString)

                let observableExpectation = QuickSpec.current.expectation(description: "awaiting observable")

                _ = resource().rx.state()
                        .do(onNext: { expect($0.latestError).to(beNil()) })
                        .compactMap { $0.content as String? }
                        .do(onNext:
                            {
                            _ in
                            // would be nice if Nocilla let us tee up a series of responses
                            _ = stubRequest(resource, "GET")
                                    .andReturn(200)
                                    .withHeader("Content-type", "text/plain")
                                    .withBody("whoo baa" as NSString)

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
                _ = stubRequest(resource, "GET")
                        .andReturn(404)

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
                _ = stubRequest(resource, "GET")
                        .andReturn(200)
                        .withHeader("Content-type", "application/json")
                        .withBody("{}" as NSString)

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


        describe("content()")
            {
            it("outputs content changes")
                {
                _ = stubRequest(resource, "GET")
                        .andReturn(200)
                        .withHeader("Content-type", "text/plain")
                        .withBody("pee hoo" as NSString)

                let observableExpectation = QuickSpec.current.expectation(description: "awaiting observable")

                _ = resource().rx.content()
                        .do(onNext:
                            {
                            (_: String) in
                            // would be nice if Nocilla let us tee up a series of responses
                            _ = stubRequest(resource, "GET")
                                    .andReturn(200)
                                    .withHeader("Content-type", "text/plain")
                                    .withBody("whoo baa" as NSString)

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
            }

        describe("request()")
            {
            it("completes when the request succeeds")
                {
                _ = stubRequest(resource, "POST")
                        .andReturn(200)

                let expectation = QuickSpec.current.expectation(description: "awaiting completion")

                _ = resource().rx.request { $0.request(.post) }
                        .subscribe(onCompleted: { expectation.fulfill() })

                QuickSpec.current.waitForExpectations(timeout: 1)
                }

            it("fails when the request fails")
                {
                _ = stubRequest(resource, "POST")
                        .andReturn(500)

                let expectation = QuickSpec.current.expectation(description: "awaiting error")

                _ = resource().rx.request { $0.request(.post) }
                        .subscribe(onError: { _ in expectation.fulfill() })

                QuickSpec.current.waitForExpectations(timeout: 1)
                }
            }

        describe("requestWithData()")
            {
            it("outputs content when the request succeeds")
                {
                _ = stubRequest(resource, "POST")
                        .andReturn(200)
                        .withHeader("Content-type", "text/plain")
                        .withBody("whoo baa" as NSString)

                let expectation = QuickSpec.current.expectation(description: "awaiting completion")

                _ = resource().rx.requestWithData { $0.request(.post) }
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
                _ = stubRequest(resource, "POST")
                        .andReturn(500)

                let expectation = QuickSpec.current.expectation(description: "awaiting error")

                _ = resource().rx.requestWithData { $0.request(.post) }
                        .subscribe(
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

        _ = takeUntil(.inclusive)
            {
            elt in
            var res: Bool?
            let fe = gatherFailingExpectations { res = testNext(elt) }
            return res! || !fe.isEmpty
            }
            .subscribe(onDisposed: { observableExpectation.fulfill() })

        QuickSpec.current.waitForExpectations(timeout: 1)
        }
    }
