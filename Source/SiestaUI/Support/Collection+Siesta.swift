//
//  Collection+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/7/19.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

extension Collection
    {
    // Just for readability
    func any(match predicate: (Iterator.Element) -> Bool) -> Bool
        { return contains(where: predicate) }

    func all(match predicate: (Iterator.Element) -> Bool) -> Bool
        { return !contains(where: { !predicate($0) }) }
    }
