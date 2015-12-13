//
//  String+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/6/22.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

internal extension String
    {
    func stripPrefix(prefix: String) -> String
        {
        return hasPrefix(prefix)
            ? self[startIndex.advancedBy(prefix.characters.count) ..< endIndex]
            : self
        }

    var capitalizedFirstCharacter: String
        {
        guard !self.isEmpty else
            { return self }

        var result = self
        result.replaceRange(startIndex...startIndex, with: String(self[startIndex]).uppercaseString)
        return result
        }

    var nilIfEmpty: String?
        {
        return isEmpty ? nil : self
        }
    }
