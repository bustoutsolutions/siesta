//
//  RxSwiftSpec.swift
//  Siesta
//
//  Created by Adrian Ross on 15/04/20.
//  Copyright (c) 2020 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble
import Nocilla
import RxSwift

// todo more cases
// todo add to macOS and tvOS

class RxSwiftSpec: ResourceSpecBase {
    override func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource) {

        describe("state()") {

            it("outputs parsed content") {
                _ = stubRequest(resource, "GET")
                        .andReturn(200)
                        .withHeader("Content-type", "text/plain")
                        .withBody("pee hoo" as NSString)

                let loadingExpectation = QuickSpec.current.expectation(description: "isLoading set")
                let requestingExpectation = QuickSpec.current.expectation(description: "isRequesting set")
                let newDataEventExpectation = QuickSpec.current.expectation(description: "awaiting newData event")

                resource().rx.state()
                        .expectNoErrors()
                        .subscribeUntilTested { (state: ResourceState<String>) in
                            if state.isLoading {loadingExpectation.fulfill() }
                            if state.isRequesting { requestingExpectation.fulfill() }
                            if case .newData = state.latestEvent { newDataEventExpectation.fulfill() }

                            if let content = state.content {
                                expect(content).to(equal("pee hoo"))
                                return true
                            }
                            return false
                        }
            }

            it("outputs content changes") {
                _ = stubRequest(resource, "GET")
                        .andReturn(200)
                        .withHeader("Content-type", "text/plain")
                        .withBody("pee hoo" as NSString)

                let observableExpectation = QuickSpec.current.expectation(description: "awaiting observable")

                _ = resource().rx.state()
                        .debug()
                        .expectNoErrors()
                        .compactMap { $0.content as String? }
                        .do(onNext: { _ in
                            _ = stubRequest(resource, "GET")
                                    .andReturn(200)
                                    .withHeader("Content-type", "text/plain")
                                    .withBody("whoo baa" as NSString)

                            resource().load()
                        })
                        .distinctUntilChanged()
                        .take(2)
                        .toArray()
                        .subscribe(onSuccess: {
                            expect($0) == ["pee hoo", "whoo baa"]
                            observableExpectation.fulfill()
                        })

                QuickSpec.current.waitForExpectations(timeout: 1)
            }

            it("outputs errors") {
                _ = stubRequest(resource, "GET")
                        .andReturn(404)

                resource().rx.state()
                        .subscribeUntilTested { (state: ResourceState<String>) in
                            if state.latestError != nil {
                                return true
                            }
                            return false
                        }
            }

            it("outputs an error if the content type is wrong") {
                _ = stubRequest(resource, "GET")
                        .andReturn(200)
                        .withHeader("Content-type", "application/json")
                        .withBody("{}" as NSString)

                resource().rx.state()
                        .subscribeUntilTested { (state: ResourceState<String>) in
                            if let error = state.latestError {
                                expect(error.cause).to(beAKindOf(RequestError.Cause.WrongContentType.self))
                                return true
                            }
                            return false
                        }
            }
        }
    }
}

extension Observable {

    fileprivate func subscribeUntilTested(testNext: @escaping (Element) -> Bool) {
        let observableExpectation = QuickSpec.current.expectation(description: "awaiting observable")

        _ = takeUntil(.inclusive) { elt in
            var res: Bool? = nil
            let fe = gatherFailingExpectations {
                res = testNext(elt)
            }
            return res! || !fe.isEmpty
        }
                .subscribe(onDisposed: {
                    // any earlier and we still have a reference to the resource
                    observableExpectation.fulfill()
                })

        QuickSpec.current.waitForExpectations(timeout: 1)
    }

    fileprivate func expectNoErrors<T>() -> Observable<ResourceState<T>> where Element == ResourceState<T> {
        `do`(onNext: {
            expect($0.latestError).to(beNil())
        })
    }
}

