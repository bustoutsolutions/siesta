//
//  ResourceTests.swift
//  Siesta
//
//  Created by Paul on 2015/6/20.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

@testable import Siesta
import Quick
import Nimble
import Nocilla
import Alamofire

class ResourceSpecBase: QuickSpec
    {
    func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        { }
    
    override final func spec()
        {
        beforeSuite { Siesta.debug = true }
        
        beforeSuite { LSNocilla.sharedInstance().start() }
        afterSuite  { LSNocilla.sharedInstance().stop() }
        afterEach   { LSNocilla.sharedInstance().clearStubs() }
        
        beforeEach  { Manager.sharedInstance.startRequestsImmediately = true }  // default, but some tests change it
        
        var originalNowProvider = now
        beforeEach { originalNowProvider = now }
        afterEach  { now = originalNowProvider }
        
        let service  = specVar { Service(base: "https://zingle.frotz/v1") },
            resource = specVar { service().resource("/a/b") }
        
        resourceSpec(service, resource)
        }
    }


// MARK: - Request stubbing

func stubReqest(resource: () -> Resource, _ method: String) -> LSStubRequestDSL
    {
    return stubRequest(method, resource().url!.absoluteString)
    }

func awaitResponse(req: Siesta.Request)
    {
    let expectation = QuickSpec.current().expectationWithDescription("network call: \(req)")
    req.response { _ in expectation.fulfill() }
    QuickSpec.current().waitForExpectationsWithTimeout(1, handler: nil)
    }

func awaitFailure(req: Siesta.Request)
    {
    let responseExpectation = QuickSpec.current().expectationWithDescription("awaiting response: \(req)")
    let errorExpectation = QuickSpec.current().expectationWithDescription("awaiting failure: \(req)")
    req.error       { _ in responseExpectation.fulfill() }
       .response    { _ in errorExpectation.fulfill() }
       .success     { _ in fail("success callback should not be called") }
       .newData     { _ in fail("newData callback should not be called") }
       .notModified { _ in fail("notModified callback should not be called") }
    QuickSpec.current().waitForExpectationsWithTimeout(1, handler: nil)
    }

func delayRequestsForThisSpec()
    {
    Manager.sharedInstance.startRequestsImmediately = false
    }

func startDelayedRequest(req: Siesta.Request)
    {
    (req as? AlamofireSiestaRequest)?.alamofireRequest?.resume()
    }

// MARK: - Clock stubbing

func setResourceTime(time: NSTimeInterval)
    {
    now = { time }
    }
