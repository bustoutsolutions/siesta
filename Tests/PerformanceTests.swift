//
//  PerformanceTests.swift
//  Siesta
//
//  Created by Paul on 2016/9/27.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation
import Quick

class SiestaPerformanceTests: XCTestCase
    {
    func testForSmoke()
        {
        measure
            { print("Gee, looks fast to me. Why worry?") }
        }
    }
