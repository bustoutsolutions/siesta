//
//  CombineSpec.swift
//  Siesta
//
//  Created by Adrian on 2020/4/27.
//  Copyright © 2020 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble
import Combine

@available(iOS 13, tvOS 13, OSX 10.15, *)
class ResourceCombineSpec: ResourceSpecBase
    {
    private var subs = [AnyCancellable]()

    override func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource)
        {
        describe("state()")
            {
            it("outputs content when the request succeeds")
                {
                NetworkStub.add(
                    .get, resource,
                    returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "pee hoo"))

                var loadingExpectation: XCTestExpectation? = QuickSpec.current.expectation(description: "isLoading set")
                var requestingExpectation: XCTestExpectation? = QuickSpec.current.expectation(description: "isRequesting set")
                let newDataEventExpectation = QuickSpec.current.expectation(description: "awaiting newData event")

                resource().statePublisher()
                        .sinkUntilTested
                            {
                            (state: ResourceState<String>) in
                            expect(state.latestError).to(beNil())
                            if state.isLoading {
                                loadingExpectation?.fulfill()
                                loadingExpectation = nil
                            }
                            if state.isRequesting {
                                requestingExpectation?.fulfill()
                                requestingExpectation = nil
                            }
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
                    resource().statePublisher()
                        .compactMap
							{ (state: ResourceState<String>) in
                            state.content != nil ? resource().statePublisher() : nil
                        	}
                        .prefix(1)
                        .switchToLatest()
                        .sink
							{ (state: ResourceState<String>) in
                            if let s = state.content
								{
                                expect(s) == "pee hoo"
                                observableExpectation.fulfill()
                            	}
                        	}
                    .store(in: &self.subs)

                    QuickSpec.current.waitForExpectations(timeout: 1)
                    self.subs.removeAll()
                	}


                it("outputs content again when it changes")
                    {
                    NetworkStub.add(
                        .get, resource,
                        returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "pee hoo"))

                    let observableExpectation = QuickSpec.current.expectation(description: "awaiting observable")

                    resource().statePublisher()
                            .compactMap { $0.content as String? }
                            .handleEvents(receiveOutput:
                                {
                                _ in
                                NetworkStub.add(
                                    .get, resource,
                                    returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "whoo baa"))

                                resource().load()
                                })
                            .removeDuplicates()
                            .prefix(2)
                            .collect()
                            .sink
                                {
                                expect($0) == ["pee hoo", "whoo baa"]
                                observableExpectation.fulfill()
                                }
                            .store(in: &self.subs)

                    QuickSpec.current.waitForExpectations(timeout: 1)
                    self.subs.removeAll()
                    }

                it("outputs an error when the request fails")
                    {
                    NetworkStub.add(.get, resource, status: 404)

                    resource().statePublisher()
                            .sinkUntilTested
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

                    resource().statePublisher()
                            .sinkUntilTested
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

                it("combines correctly with other operators")
                    {
                    NetworkStub.add(
                        .get, resource,
                        returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "pee hoo"))

                    resource()
                        .statePublisher()
                        .combineLatest(Publishers.Sequence(sequence: 1...10))
                        .sinkUntilTested
                            {
                            (state: ResourceState<String>, i: Int) in
                            if let content = state.content
                                {
                                expect(content) == "pee hoo"
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
                    NetworkStub.add(
                        .get, resource,
                        returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "pee hoo"))

                    let observableExpectation = QuickSpec.current.expectation(description: "awaiting observable")

                    resource().contentPublisher()
                            .handleEvents(receiveOutput:
                                {
                                (_: String) in
                                NetworkStub.add(
                                    .get, resource,
                                    returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "whoo baa"))

                                resource().load()
                                })
                            .removeDuplicates()
                            .prefix(2)
                            .collect()
                            .sink
                                {
                                expect($0) == ["pee hoo", "whoo baa"]
                                observableExpectation.fulfill()
                                }
                            .store(in: &self.subs)

                    QuickSpec.current.waitForExpectations(timeout: 1)
                    self.subs.removeAll()
                    }

                it("outputs content when the content is already cached")
                    {
                    NetworkStub.add(
                        .get, resource,
                        returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "pee hoo"))

                    let observableExpectation = QuickSpec.current.expectation(description: "awaiting observable")
                    resource().contentPublisher()
                        .prefix(1)
                        .map { (_: String) in resource().contentPublisher() }
                        .switchToLatest()
                        .sink
							{ (s: String) in
                            expect(s) == "pee hoo"
                            observableExpectation.fulfill()
                        	}
                        .store(in: &self.subs)

                    QuickSpec.current.waitForExpectations(timeout: 1)
                    self.subs.removeAll()
                    }
                }

            describe("request()")
                {
                it("outputs content when the request succeeds")
                    {
                    NetworkStub.add(
                        .post, resource,
                        returning: HTTPResponse(headers: ["Content-type": "text/plain"], body: "whoo baa"))

                    let expectation = QuickSpec.current.expectation(description: "awaiting completion")

                    resource().dataRequestPublisher { $0.request(.post) }
                        .sink(
                                receiveCompletion: { _ in },
                                receiveValue:
                            {
                            (s: String) in
                            expect(s) == "whoo baa"
                            expectation.fulfill()
                            })
                        .store(in: &self.subs)

                    QuickSpec.current.waitForExpectations(timeout: 1)
                    self.subs.removeAll()
                    }

                it("fails when the request fails")
                    {
                    NetworkStub.add(.post, resource, status: 500)

                    let expectation = QuickSpec.current.expectation(description: "awaiting error")

                    resource().dataRequestPublisher { $0.request(.post) }
                            .sink(
                                    receiveCompletion:
										{ if case .failure = $0 { expectation.fulfill() } },
                                    receiveValue:
										{ (_: String) in })
                            .store(in: &self.subs)

                        QuickSpec.current.waitForExpectations(timeout: 1)
                        self.subs.removeAll()
                    }

                it("completes successfully without output when the request has no output")
                    {
                    NetworkStub.add(
                        .post, resource,
                        status: 200)

                    let expectation = QuickSpec.current.expectation(description: "awaiting completion")

                        resource().requestPublisher { $0.request(.post) }
                            .sink(
                                    receiveCompletion:
										{ _ in expectation.fulfill() },
                                    receiveValue:
										{ _ in })
                            .store(in: &self.subs)

                    QuickSpec.current.waitForExpectations(timeout: 1)
                        self.subs.removeAll()
                    }

                it("fails when a request without output fails")
                    {
                    NetworkStub.add(.post, resource, status: 500)

                    let expectation = QuickSpec.current.expectation(description: "awaiting error")

                    resource().requestPublisher { $0.request(.post) }
                            .sink(
                                    receiveCompletion:
										{ if case .failure = $0 { expectation.fulfill() } },
                                    receiveValue:
										{ _ in })
                            .store(in: &self.subs)

                    QuickSpec.current.waitForExpectations(timeout: 1)
                    self.subs.removeAll()
                    }
				}
        }
    }

@available(iOS 13, tvOS 13, OSX 10.15, *)
extension Publisher
    {
    fileprivate func sinkUntilTested(timeout: TimeInterval = 1, testNext: @escaping (Output) -> Bool)
		{
        let observableExpectation = QuickSpec.current.expectation(description: "awaiting observable")

        let sub = prefix
            { elt in
            var finished: Bool?
            let fe = gatherFailingExpectations { finished = testNext(elt) }
            return (finished == nil || finished == false) && fe.isEmpty
            }
            .sink(receiveCompletion: { _ in observableExpectation.fulfill() }, receiveValue: { _ in })

        QuickSpec.current.waitForExpectations(timeout: timeout)
        expect(sub).notTo(beNil()) // silence Xcode's warning
        }
    }
