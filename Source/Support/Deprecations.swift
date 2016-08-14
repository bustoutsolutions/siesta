//
//  Deprecations.swift
//  Siesta
//
//  Created by Paul on 2015/12/12.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//


import Foundation

// MARK: - Deprecated in beta 9

extension Request
    {
    @available(*, deprecated=0.99, message="Your onCompletion() should take ResponseInfo instead of Response. If you’re using $0, replace it with $0.response.")
    public func onCompletion(callback: Response -> Void) -> Self
        {
        return onCompletion { callback($0.response) }
        }
    }

