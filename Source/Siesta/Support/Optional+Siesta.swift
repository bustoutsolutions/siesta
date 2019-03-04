//
//  Optional+Siesta.swift
//  Siesta
//
//  Created by Paul on 2019/3/3.
//  Copyright © 2019 Bust Out Solutions. All rights reserved.
//

import Foundation

extension Optional
    {
    /// Siesta uses this instead of the bare force unwrap operator !
    func forceUnwrapped(because assumption: String) -> Wrapped
        {
        guard let self = self else
            { fatalError("Unexpectedly found nil unwrapping an Optional. Failed assumption: \(assumption)") }
        return self
        }
    }
