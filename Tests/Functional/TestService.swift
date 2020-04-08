//
//  TestService.swift
//  Siesta
//
//  Created by Paul on 2015/8/7.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta

import Foundation
import Quick

@objc
public class TestService: Service  // for Obj-C tests only
    {
    private var allRequests = [Request]()

    @objc
    public init()
        {
        super.init(
            baseURL: "http://example.api",
            networking: NetworkStub.wrap(URLSessionConfiguration.ephemeral))

        configure
            {
            $0.decorateRequests
                {
                _, request in
                self.allRequests.append(request)
                return request
                }
            }
        }

    @objc
    public func awaitAllRequests()
        {
        for req in allRequests
            {
            let responseExpectation = QuickSpec.current.expectation(description: "awaiting response callback: \(req)")
            req.onCompletion { _ in responseExpectation.fulfill() }
            QuickSpec.current.waitForExpectations(timeout: 1)
            }
        allRequests = []
        }
    }
