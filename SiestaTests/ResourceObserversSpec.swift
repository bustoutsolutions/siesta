//
//  ResourceObserversSpec.swift
//  Siesta
//
//  Created by Paul on 2015/7/5.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble
import Nocilla
import Alamofire

class ResourceObserversSpec: ResourceSpecBase
    {
    override func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        {
        describe("observer")
            {
            let observer = specVar { TestObserverWithExpectations() }
            
            beforeEach
                {
                observer().expect(.OBSERVER_ADDED)
                resource().addObserver(observer())
                }
            
            it("receives a notification that it was added")
                {
                let observer2 = TestObserverWithExpectations()
                observer2.expect(.OBSERVER_ADDED)  // only for new observer
                resource().addObserver(observer2)
                }
            
            it("is chainable")
                {
                let observer2 = TestObserverWithExpectations(),
                    observer3 = TestObserverWithExpectations()
                observer2.expect(.OBSERVER_ADDED)
                observer3.expect(.OBSERVER_ADDED)
                resource().addObserver(observer2).addObserver(observer3)
                }
            
            it("receives request event")
                {
                stubReqest(resource, "GET").andReturn(200)
                observer().expect(.REQUESTED)
                    {
                    expect(resource().loading).to(beTrue())
                    expect(resource().latestData).to(beNil())
                    expect(resource().latestError).to(beNil())
                    }
                let req = resource().load()
                
                // Let Nocilla check off request without any further observing
                resource().removeObservers(ownedBy: observer())
                awaitResponse(req)
                }
            
            it("receives new data event")
                {
                stubReqest(resource, "GET").andReturn(200)
                observer().expect(.REQUESTED)
                observer().expect(.NEW_DATA_RESPONSE)
                    {
                    expect(resource().loading).to(beFalse())
                    expect(resource().latestData).notTo(beNil())
                    expect(resource().latestError).to(beNil())
                    }
                awaitResponse(resource().load())
                }
            
            it("receives not modified event")
                {
                stubReqest(resource, "GET").andReturn(304)
                observer().expect(.REQUESTED)
                observer().expect(.NOT_MODIFIED_RESPONSE)
                    {
                    expect(resource().loading).to(beFalse())
                    }
                awaitResponse(resource().load())
                }

            it("receives cancel event")
                {
                stubReqest(resource, "GET").andReturn(200)
                observer().expect(.REQUESTED)
                observer().expect(.REQUEST_CANCELLED)
                    {
                    expect(resource().loading).to(beFalse())
                    }
                let req = resource().load()
                req.cancel()
                awaitResponse(req)
                }
            
            it("receives failure event")
                {
                stubReqest(resource, "GET").andReturn(500)
                observer().expect(.REQUESTED)
                observer().expect(.ERROR_RESPONSE)
                    {
                    expect(resource().loading).to(beFalse())
                    expect(resource().latestData).to(beNil())
                    expect(resource().latestError).notTo(beNil())
                    }
                awaitResponse(resource().load())
                }
            
            it("does not receive notifications for request(), only load()")
                {
                stubReqest(resource, "GET").andReturn(200)
                awaitResponse(resource().request(.GET))
                }
            }
            
        describe("memory management")
            {
            it("prevents the resource from being deallocated while it has observers")
                {
                var resource: Resource? = service().resource("zargle")
                weak var resourceWeak = resource
                let observer = TestObserver()
                resource?.addObserver(observer)
                resource = nil
                
                simulateMemoryWarning()
                expect(resourceWeak).notTo(beNil())
                
                resourceWeak?.removeObservers(ownedBy: observer)
                simulateMemoryWarning()
                expect(resourceWeak).to(beNil())
                }
            
            it("stops observing when observer is deallocated")
                {
                var observer: TestObserverWithExpectations? = TestObserverWithExpectations()
                weak var observerWeak = observer
                observer!.expect(.OBSERVER_ADDED)
                observer!.expect(.REQUESTED)
                resource().addObserver(observer!)
                
                let req = resource().load()
                observer!.checkForUnfulfilledExpectations()
                
                observer = nil
                expect(observerWeak).to(beNil())  // resource should not have retained it
                
                // No expectations, so this will fail if Resource still notifies observer
                stubReqest(resource, "GET").andReturn(200)
                awaitResponse(req)
                }
            
            it("stops observing when owner is deallocated")
                {
                let observer = TestObserverWithExpectations()
                var owner: AnyObject? = "foo"
                observer.expect(.OBSERVER_ADDED)
                resource().addObserver(observer, owner: owner!)
                
                observer.expect(.REQUESTED)
                let req = resource().load()
                observer.checkForUnfulfilledExpectations()
                
                owner = nil
                stubReqest(resource, "GET").andReturn(200)
                awaitResponse(req)  // make sure Resource doesn't blow up
                }
            }
        }
    }



// MARK: - Observer stubs/mocks

private class TestObserver: ResourceObserver
    {
    func resourceChanged(resource: Resource, event: ResourceEvent) { }
    }

private class TestObserverWithExpectations: ResourceObserver
    {
    private var expectedEvents = [Expectation]()
    
    deinit
        { checkForUnfulfilledExpectations() }
    
    func expect(event: ResourceEvent, callback: (Void -> Void) = {})
        { expectedEvents.append(Expectation(event: event, callback: callback)) }
    
    func checkForUnfulfilledExpectations()
        {
        if !expectedEvents.isEmpty
            { XCTFail("Expected observer events, but never received them: \(expectedEvents.map { $0.event })") }
        }
    
    func resourceChanged(resource: Resource, event: ResourceEvent)
        {
        if expectedEvents.isEmpty
            { XCTFail("Received unexpected observer event: \(event)") }
        else
            {
            let expectation = expectedEvents.removeAtIndex(0)
            if event != expectation.event
                { XCTFail("Received unexpected observer event: \(event) (was expecting \(expectation.event))") }
            else
                { expectation.callback() }
            }
        }
    
    struct Expectation
        {
        let event: ResourceEvent
        let callback: (Void -> Void)
        
        func description() -> String
            { return "\(event)" }
        }
    }
