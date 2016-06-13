//
//  Deprecations.swift
//  Siesta
//
//  Created by Paul on 2015/12/12.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//


import Foundation

// MARK: - Deprecated in beta 7

extension Resource
    {
    @available(*, deprecated=0.99, message="This property is going away from the public API. If you have a need for it, please file a Github issue describing your use case.")
    public var config: Configuration
        { return generalConfig }
    }

