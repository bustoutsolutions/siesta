//
//  ΩDeprecations.swift  ← Ω prefix forces CocoaPods to build this last, which matters for nested type extensions
//  Siesta
//
//  Created by Paul on 2015/12/12.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//


import Foundation

// MARK: Swift 3 deprecations

extension Configuration
    {
    @available(*, unavailable, message: "Globally replace `$0.config` with `$0`")
    public var config: Configuration
        {
        get { fatalError("no longer available") }
        set { fatalError("no longer available") }
        }
    }
