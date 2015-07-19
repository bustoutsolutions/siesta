//
//  Collection+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/7/19.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

extension CollectionType
    {
    func bipartition(
            @noescape includeElement: (Self.Generator.Element) -> Bool)
        -> (included: [Self.Generator.Element], excluded: [Self.Generator.Element])
        {
        var included: [Self.Generator.Element] = []
        var excluded: [Self.Generator.Element] = []
        
        for elem in self
            {
            if(includeElement(elem))
                { included.append(elem) }
            else
                { excluded.append(elem) }
            }
        
        return (included: included, excluded: excluded)
        }
    }
