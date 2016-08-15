//
//  ΩDeprecations.swift  ← Ω prefix forces CocoaPods to build this last, which matters for nested type extensions
//  Siesta
//
//  Created by Paul on 2015/12/12.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//


import Foundation

// Deprecated in 1.0-beta.9

extension Error.Cause
    {
    @available(*, deprecated=0.99, renamed="WrongInputTypeInTranformerPipeline")
    public typealias WrongTypeInTranformerPipeline = Error.Cause.WrongInputTypeInTranformerPipeline
    }
