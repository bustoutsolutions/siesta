//
//  String+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/6/22.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

internal extension String
    {
    func stripPrefix(_ prefix: String) -> String
        {
        return hasPrefix(prefix)
            ? self[characters.index(startIndex, offsetBy: prefix.characters.count) ..< endIndex]
            : self
        }

    func replacingPrefix(_ prefix: String, with replacement: String) -> String
        {
        return hasPrefix(prefix)
            ? replacement + stripPrefix(prefix)
            : self
        }

    var capitalized: String
        {
        guard !isEmpty else
            { return self }
        let secondCharIndex = index(after: startIndex)
        return substring(to: secondCharIndex).uppercased()
             + substring(from: secondCharIndex)
        }
    var nilIfEmpty: String?
        {
        return isEmpty ? nil : self
        }
    }
