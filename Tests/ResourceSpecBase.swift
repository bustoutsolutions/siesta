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

func awaitResponse(req: Request)
    {
    let expectation = QuickSpec.current().expectationWithDescription("network call: \(req)")
    req.response { _ in expectation.fulfill() }
    QuickSpec.current().waitForExpectationsWithTimeout(1, handler: nil)
    }


// MARK: - Clock stubbing

func setResourceTime(time: NSTimeInterval)
    {
    now = { time }
    }
