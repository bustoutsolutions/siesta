//
//  ProgressSpec.swift
//  Siesta
//
//  Created by Paul on 2015/10/4.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

@testable import Siesta
import Quick
import Nimble
import Nocilla

class ProgressSpec: ResourceSpecBase
    {
    override func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        {
        context("always reaches 1")
            {
            it("on success")
                {
                stubReqest(resource, "GET").andReturn(200)
                let req = resource().load()
                awaitNewData(req)
                expect(req.progress).to(equal(1.0))
                }
            
            it("on server error")
                {
                stubReqest(resource, "GET").andReturn(500)
                let req = resource().load()
                awaitFailure(req)
                expect(req.progress).to(equal(1.0))
                }
            
            it("on connection error")
                {
                stubReqest(resource, "GET").andFailWithError(NSError(domain: "foo", code: 1, userInfo: nil))
                let req = resource().load()
                awaitFailure(req)
                expect(req.progress).to(equal(1.0))
                }
            
            it("on cancellation")
                {
                let reqStub = stubReqest(resource, "GET").andReturn(200).delay()
                let req = resource().load()
                req.cancel()
                expect(req.progress).to(equal(1.0))
                reqStub.go()
                awaitFailure(req, alreadyCompleted: true)
                }
            }
        }
    }
