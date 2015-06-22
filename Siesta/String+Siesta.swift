//
//  String+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/6/22.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

extension String
    {
    public func stripPrefix(prefix: String) -> String
        {
        return hasPrefix(prefix)
            ? self[advance(startIndex, prefix.characters.count) ..< endIndex]
            : self
        }
    }
