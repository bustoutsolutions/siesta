//
//  ResponseDataHandlingSpec.swift
//  Siesta
//
//  Created by Paul on 2015/7/8.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble
import Nocilla
import Alamofire

class ResponseDataHandlingSpec: ResourceSpecBase
    {
    override func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        {
        describe("default parsing")
            {
            for jsonType in ["application/json", "application/foo+json", "foo/json"]
                {
                it("parses \(jsonType) as JSON")
                    {
                    stubReqest(resource, "GET").andReturn(200)
                        .withHeader("Content-Type", jsonType)
                        .withBody("{\"foo\":[\"bar\",42]}")
                    awaitResponse(resource().load())
                    
                    expect(resource().data as? Dictionary).to(equal(["foo": ["bar", 42]]))
                    }
                }

            it("reports JSON parse errors")
                {
                stubReqest(resource, "GET").andReturn(200)
                    .withHeader("Content-Type", "application/json")
                    .withBody("{\"foo\":•√£™˚")
                awaitResponse(resource().load())
                
                expect(resource().latestData).to(beNil())
                expect(resource().latestError).notTo(beNil())
                expect(resource().latestError?.userMessage).to(equal("Cannot parse JSON"))
                expect(resource().latestError?.nsError?.domain).to(equal("NSCocoaErrorDomain"))
                expect(resource().latestError?.nsError?.code).to(equal(3840))
                }
            }
        }
    }