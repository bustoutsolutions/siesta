//
//  ResourceSpecBase.swift
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

class ResourceSpecBase: SiestaSpec
    {
    func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        { }
    
    override final func spec()
        {
        super.spec()
        
        beforeSuite { LSNocilla.sharedInstance().start() }
        afterSuite  { LSNocilla.sharedInstance().stop() }
        afterEach   { LSNocilla.sharedInstance().clearStubs() }
        
        afterEach  { fakeNow = nil }
        
        let service  = specVar { Service(base: "https://\(self.apiHostname)/v1") },
            resource = specVar { service().resource("/a/b") }
        
        resourceSpec(service, resource)
        }
    
    var apiHostname: String
        {
        // Embedding the spec name in the API’s URL makes it easier to track down unstubbed requests, which sometimes
        // don’t arrive until a following spec has already started.
        
        return QuickSpec.current().description
            .replaceRegex("_[A-Za-z]+Specswift_\\d+\\]$", "")
            .replaceRegex("[^A-Za-z0-9_]+", ".")
            .replaceRegex("^\\.+|\\.+$", "")
        }
    }


// MARK: - Request stubbing

func stubReqest(resource: () -> Resource, _ method: String) -> LSStubRequestDSL
    {
    return stubRequest(method, resource().url!.absoluteString)
    }

func awaitNewData(req: Siesta.Request, alreadyCompleted: Bool = false)
    {
    expect(req.completed).to(equal(alreadyCompleted))
    let responseExpectation = QuickSpec.current().expectationWithDescription("awaiting response callback: \(req)")
    let successExpectation = QuickSpec.current().expectationWithDescription("awaiting success callback: \(req)")
    let newDataExpectation = QuickSpec.current().expectationWithDescription("awaiting newData callback: \(req)")
    req.completion  { _ in responseExpectation.fulfill() }
       .success     { _ in successExpectation.fulfill() }
       .failure     { _ in fail("error callback should not be called") }
       .newData     { _ in newDataExpectation.fulfill() }
       .notModified { _ in fail("notModified callback should not be called") }
    QuickSpec.current().waitForExpectationsWithTimeout(1, handler: nil)
    expect(req.completed).to(beTrue())
    }

func awaitNotModified(req: Siesta.Request)
    {
    expect(req.completed).to(beFalse())
    let responseExpectation = QuickSpec.current().expectationWithDescription("awaiting response callback: \(req)")
    let successExpectation = QuickSpec.current().expectationWithDescription("awaiting success callback: \(req)")
    let notModifiedExpectation = QuickSpec.current().expectationWithDescription("awaiting notModified callback: \(req)")
    req.completion  { _ in responseExpectation.fulfill() }
       .success     { _ in successExpectation.fulfill() }
       .failure     { _ in fail("error callback should not be called") }
       .newData     { _ in fail("newData callback should not be called") }
       .notModified { _ in notModifiedExpectation.fulfill() }
    QuickSpec.current().waitForExpectationsWithTimeout(1, handler: nil)
    expect(req.completed).to(beTrue())
    }

func awaitFailure(req: Siesta.Request, alreadyCompleted: Bool = false)
    {
    expect(req.completed).to(equal(alreadyCompleted))
    let responseExpectation = QuickSpec.current().expectationWithDescription("awaiting response callback: \(req)")
    let errorExpectation = QuickSpec.current().expectationWithDescription("awaiting failure callback: \(req)")
    req.completion  { _ in responseExpectation.fulfill() }
       .failure     { _ in errorExpectation.fulfill() }
       .success     { _ in fail("success callback should not be called") }
       .newData     { _ in fail("newData callback should not be called") }
       .notModified { _ in fail("notModified callback should not be called") }
    QuickSpec.current().waitForExpectationsWithTimeout(1, handler: nil)
    expect(req.completed).to(beTrue())
    }

// MARK: - Clock stubbing

func setResourceTime(time: NSTimeInterval)
    {
    fakeNow = time
    }
