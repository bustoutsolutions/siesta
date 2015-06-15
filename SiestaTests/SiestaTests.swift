//
//  SiestaTests.swift
//  SiestaTests
//
//  Created by Paul on 2015/6/14.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble

class SiestaTests: QuickSpec
    {
    override func spec()
        {
        describe("Unit testing")
            {
            it("works")
                {
                expect(Service().hello()).to(equal(2))
                }
            }
        }
    }
