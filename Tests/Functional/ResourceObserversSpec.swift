//
//  ResourceObserversSpec.swift
//  Siesta
//
//  Created by Paul on 2015/7/5.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta

import Foundation
import XCTest
import Quick
import Nimble

class ResourceObserversSpec: ResourceSpecBase
    {
    override func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource)
        {
        var observer: TestObserverWithExpectations! = nil

        beforeEach
            {
            observer = TestObserverWithExpectations()
            }

        afterEach
            {
            observer.checkForUnfulfilledExpectations()
            observer.stopTesting()
            resource().removeObservers(ownedBy: observer)
            simulateMemoryWarning()
            awaitObserverCleanup(for: resource())
            observer = nil
            }

        describe("observer")
            {
            beforeEach
                {
                observer.expect(.observerAdded)
                resource().addObserver(observer)
                }

            it("receives a notification that it was added")
                {
                let observer2 = TestObserverWithExpectations()
                observer2.expect(.observerAdded)  // only for new observer
                resource().addObserver(observer2)
                }

            it("receives a notification that it was removed")
                {
                let observer2 = TestObserverWithExpectations()
                observer2.expect(.observerAdded)  // only for new observer
                resource().addObserver(observer2)

                observer.expectStoppedObserving()
                resource().removeObservers(ownedBy: observer)
                awaitObserverCleanup(for: resource())
                }

            it("receives removal notification if not externally retained but not self-owned")
                {
                var observer2: TestObserverWithExpectations? = TestObserverWithExpectations()
                observer2?.expect(.observerAdded)
                resource().addObserver(observer2!, owner: observer)  // not self-owned

                observer.expectStoppedObserving()
                observer2!.expectStoppedObserving()
                observer2 = nil
                resource().removeObservers(ownedBy: observer)
                awaitObserverCleanup(for: resource())
                }

            it("does not receive removal notification if self-owned and not externally retained")
                {
                var observer2: TestObserverWithExpectations? = TestObserverWithExpectations()
                observer2?.expect(.observerAdded)
                resource().addObserver(observer2!)  // self-owned

                observer.expectStoppedObserving()
                // No expectStoppedObserving() for observer2!
                observer2 = nil
                resource().removeObservers(ownedBy: observer)
                awaitObserverCleanup(for: resource())
                }

            it("receives a notification every time it is removed and re-added")
                {
                let observer2 = TestObserverWithExpectations()
                for _ in 0...3
                    {
                    observer2.expect(.observerAdded)
                    resource().addObserver(observer2)
                    observer2.expectStoppedObserving()
                    resource().removeObservers(ownedBy: observer2)
                    }
                awaitObserverCleanup(for: resource())  // catch that last stoppedObserving before observer2 goes out of scope
                }

            it("is unaffected by removeObservers() with nil owner")
                {
                resource().removeObservers(ownedBy: nil)
                }

            it("is chainable")
                {
                let observer2 = TestObserverWithExpectations(),
                    observer3 = TestObserverWithExpectations()
                observer2.expect(.observerAdded)
                observer3.expect(.observerAdded)
                resource().addObserver(observer2).addObserver(observer3)
                }

            it("receives request event")
                {
                NetworkStub.add(.get, resource)
                observer.expect(.requested)
                    {
                    expect(resource().isLoading) == true
                    expect(resource().latestData).to(beNil())
                    expect(resource().latestError).to(beNil())
                    }
                let req = resource().load()

                // Let request finish without any further observing
                observer.expectStoppedObserving()
                resource().removeObservers(ownedBy: observer)
                awaitNewData(req)
                }

            it("receives new data event")
                {
                NetworkStub.add(.get, resource)
                observer.expect(.requested)
                observer.expect(.newData(.network))
                    {
                    expect(resource().isLoading) == false
                    expect(resource().latestData).notTo(beNil())
                    expect(resource().latestError).to(beNil())
                    }
                awaitNewData(resource().load())
                }

            it("receives new data event from local override")
                {
                // No .requested event!
                observer.expect(.newData(.localOverride))
                    {
                    expect(resource().isLoading) == false
                    expect(resource().latestData).notTo(beNil())
                    expect(resource().latestError).to(beNil())
                    }
                resource().overrideLocalData(with:
                    Entity<Any>(content: Data(), contentType: "crazy/test"))
                }

            it("receives not modified event")
                {
                NetworkStub.add(.get, resource)
                observer.expect(.requested)
                observer.expect(.newData(.network))
                awaitNewData(resource().load())
                NetworkStub.clearAll()

                NetworkStub.add(.get, resource, status: 304)
                observer.expect(.requested)
                observer.expect(.notModified)
                    {
                    expect(resource().isLoading) == false
                    }
                awaitNotModified(resource().load())
                }

            it("receives error if server sends not modified but no local data")
                {
                NetworkStub.add(.get, resource, status: 304)
                observer.expect(.requested)
                observer.expect(.error)
                awaitFailure(resource().load())
                expect(resource().latestError?.cause is RequestError.Cause.NoLocalDataFor304) == true
                }

            it("receives cancel event")
                {
                // delay prevents race condition between cancel() and network response
                let reqStub = NetworkStub.add(.get, resource).delay()
                observer.expect(.requested)
                observer.expect(.requestCancelled)
                    {
                    expect(resource().isLoading) == false
                    }
                let req = resource().load()
                req.cancel()
                reqStub.go()
                awaitFailure(req, initialState: .completed)
                }

            it("receives failure event")
                {
                NetworkStub.add(.get, resource, status: 500)
                observer.expect(.requested)
                observer.expect(.error)
                    {
                    expect(resource().isLoading) == false
                    expect(resource().latestData).to(beNil())
                    expect(resource().latestError).notTo(beNil())
                    }
                awaitFailure(resource().load())
                }

            it("does not receive notifications for request(), only load()")
                {
                NetworkStub.add(.get, resource)
                awaitNewData(resource().request(.get))
                }

            it("can be a closure")
                {
                observer.expectStoppedObserving()
                resource().removeObservers(ownedBy: observer)

                let dummy = NSData()
                var events = [String]()
                resource().addObserver(owner: dummy)
                    {
                    resource, event in
                    events.append(String(describing: event))
                    }

                NetworkStub.add(.get, resource)
                awaitNewData(resource().load())

                expect(events) == ["observerAdded", "requested", "newData(network)"]

                resource().removeObservers(ownedBy: dummy)
                }

            it("can have multiple closure observers")
                {
                observer.expect(.requested, .newData(.network), .requested, .newData(.network))

                let dummy = NSData()
                var events0 = [String](),
                    events1 = [String]()

                resource().addObserver(owner: dummy)
                    { _, event in events0.append(String(describing: event)) }

                NetworkStub.add(.get, resource)
                awaitNewData(resource().load())

                resource().addObserver(owner: dummy)
                    { _, event in events1.append(String(describing: event)) }

                awaitNewData(resource().load())

                expect(events0) == ["observerAdded", "requested", "newData(network)", "requested", "newData(network)"]
                expect(events1) == ["observerAdded", "requested", "newData(network)"]

                resource().removeObservers(ownedBy: dummy)
                }

            it("is not added twice if it is an object")
                {
                resource().addObserver(observer)
                resource().addObserver(observer)

                NetworkStub.add(.get, resource)
                observer.expect(.requested)
                observer.expect(.newData(.network))
                awaitNewData(resource().load())
                }

            describe("with multiple owners")
                {
                let owner1 = NSData(),
                    owner2 = NSString()

                beforeEach
                    {
                    resource().addObserver(observer, owner: owner1)
                    resource().addObserver(observer, owner: owner2)
                    }

                afterEach
                    {
                    resource().removeObservers(ownedBy: owner1)
                    resource().removeObservers(ownedBy: owner2)
                    }

                func expectStillObserving(_ stillObserving: Bool)
                    {
                    NetworkStub.add(.get, resource)
                    if stillObserving
                        {
                        observer.expect(.requested)
                        observer.expect(.newData(.network))
                        }
                    if !stillObserving
                        { observer.expectStoppedObserving() }
                    awaitObserverCleanup(for: resource())
                    awaitNewData(resource().load())
                    }


                it("is not removed if self-ownership is not removed")
                    {
                    resource().removeObservers(ownedBy: owner1)
                    resource().removeObservers(ownedBy: owner2)
                    expectStillObserving(true)
                    }

                it("is not removed if external owner is not removed")
                    {
                    resource().removeObservers(ownedBy: observer)
                    resource().removeObservers(ownedBy: owner2)
                    expectStillObserving(true)
                    }

                it("is removed when all owners are removed")
                    {
                    resource().removeObservers(ownedBy: observer)
                    resource().removeObservers(ownedBy: owner1)
                    resource().removeObservers(ownedBy: owner2)
                    expectStillObserving(false)
                    }
                }
            }

        describe("resource memory management")
            {
            weak var resourceWeak: Resource?

            beforeEach
                {
                var resource: Resource? = service().resource("zargle")
                resourceWeak = resource
                observer.expect(.observerAdded)
                resource?.addObserver(observer)
                resource = nil
                }

            afterEach
                { resourceWeak = nil }

            func expectResourceToBeRetained()
                {
                awaitObserverCleanup(for: resourceWeak)
                simulateMemoryWarning()
                expect(resourceWeak).notTo(beNil())
                }

            func expectResourceNotToBeRetained()
                {
                awaitObserverCleanup(for: resourceWeak)
                simulateMemoryWarning()
                expect(resourceWeak).to(beNil())
                }

            it("prevents the resource from being deallocated while it has observers")
                {
                expectResourceToBeRetained()
                }

            it("allows resource deallocation when no observers left")
                {
                observer.expectStoppedObserving()
                resourceWeak?.removeObservers(ownedBy: observer)
                expectResourceNotToBeRetained()
                }

            it("allows resource deallocation when observer owners are deallocated")
                {
                var otherOwner: AnyObject? = TestObserver()
                resourceWeak?.addObserver(observer, owner: otherOwner!)
                resourceWeak?.removeObservers(ownedBy: observer)
                expectResourceToBeRetained()

                otherOwner = nil
                observer.expectStoppedObserving()
                expectResourceNotToBeRetained()
                }

            it("re-retains resource when observers added again")
                {
                observer.expectStoppedObserving()
                resourceWeak?.removeObservers(ownedBy: observer)
                observer.expect(.observerAdded)
                resourceWeak?.addObserver(observer)
                expectResourceToBeRetained()
                }

            it("reeastablishes strong observer ref when owner re-added")
                {
                var observer2: TestObserver? = TestObserver()
                weak var weakObserver2 = observer2

                resourceWeak?.addObserver(observer2!, owner: observer)  // strong ref to observer2
                resourceWeak?.addObserver(observer2!)
                observer.expectStoppedObserving()
                resourceWeak?.removeObservers(ownedBy: observer)        // now only has weak ref to observer2
                resourceWeak?.addObserver(observer2!, owner: observer)  // strong ref reestablished

                observer2 = nil
                expect(weakObserver2).notTo(beNil())
                expectResourceToBeRetained()
                }
            }

        describe("observer auto-removal")
            {
            func expectToStopObservation(
                    _ observer: () -> TestObserverWithExpectations,  // closure b/c we don't want to retain it as param
                    callbackThatShouldCauseRemoval: () -> Void)
                {
                observer().expect(.requested)

                // Start request; observer should hear about it

                let reqStub = NetworkStub.add(.get, resource).delay()
                let req = resource().load()
                observer().checkForUnfulfilledExpectations()

                callbackThatShouldCauseRemoval()

                // No observer expectations left, so this will fail if Resource still notifies observer
                reqStub.go()
                awaitNewData(req)
                }

            it("stops observing when self-owned observer is deallocated")
                {
                var observer: TestObserverWithExpectations? = TestObserverWithExpectations()
                weak var observerWeak = observer

                observer!.expect(.observerAdded)
                resource().addObserver(observer!)

                expectToStopObservation({ observer! })
                    {
                    observer = nil
                    // Note: observer does _not_ receive stoppedObserving because it’s deallocated before we can send it
                    }

                expect(observerWeak).to(beNil())  // resource should not have retained it
                }

            it("stops observing when owner is deallocated")
                {
                let observer = TestObserverWithExpectations()
                var owner: AnyObject? = NSObject()

                observer.expect(.observerAdded)
                resource().addObserver(observer, owner: owner!)

                expectToStopObservation({ observer })
                    {
                    owner = nil
                    observer.expectStoppedObserving()
                    }
                }
            }
        }
    }


// MARK: - Observer stubs/mocks

private class TestObserver: ResourceObserver
    {
    func resourceChanged(_ resource: Resource, event: ResourceEvent) { }
    }

private class TestObserverWithExpectations: ResourceObserver
    {
    private var expectedEvents: [Expectation] = []
    private var testing = true

    func expect(_ events: ResourceEvent..., callback: @escaping (() -> Void) = {})
        {
        for event in events
            { expectedEvents.append(Expectation(event: "\(event)", callback: callback)) }
        }

    func expectStoppedObserving()
        {
        expectedEvents.append(Expectation(event: "stoppedObserving") { })
        }

    func checkForUnfulfilledExpectations()
        {
        if !expectedEvents.isEmpty
            { XCTFail("Expected observer events, but never received them: \(expectedEvents.map(\.event))") }
        }

    func stopTesting()
        {
        testing = false
        }

    func resourceChanged(_ resource: Resource, event: ResourceEvent)
        {
        consume(event: "\(event)")
        }

    func stoppedObserving(resource: Resource)
        {
        consume(event: "stoppedObserving")
        }

    private func consume(event: String)
        {
        guard testing else
            { return }

        if expectedEvents.isEmpty
            { XCTFail("Received unexpected observer event: \(event)") }
        else
            {
            let expectation = expectedEvents.remove(at: 0)
            if String(describing: event) != String(describing: expectation.event)
                { XCTFail("Received unexpected observer event: \(event) (was expecting \(expectation.event))") }
            else
                { expectation.callback() }
            }
        }

    private struct Expectation
        {
        let event: String
        let callback: (() -> Void)

        func description() -> String
            { event }
        }
    }
