//
//  ΩDeprecations.swift  ← Ω prefix forces CocoaPods to build this last, which matters for nested type extensions
//  Siesta
//
//  Created by Paul on 2015/12/12.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

extension Service
    {
    @available(*, deprecated: 0.99, message: "Use `standardTransformers:` instead of `useDefaultTransformers:`. Choices are `[.json, .text, .image]`; use [] for none")
    public convenience init(
            baseURL: URLConvertible? = nil,
            useDefaultTransformers: Bool,
            networking: NetworkingProviderConvertible = URLSessionConfiguration.ephemeral)
        {
        if useDefaultTransformers
            { self.init(baseURL: baseURL, networking: networking) }
        else
            { self.init(baseURL: baseURL, standardTransformers: [], networking: networking) }
        }
    }
