//
//  NSURL+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/7/17.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Foundation

internal extension NSURL
    {
    func alterPath(pathMutator: String -> String) -> NSURL?
        {
        guard let components = NSURLComponents(URL: self, resolvingAgainstBaseURL: true) else
            { return nil }

        let path = pathMutator(components.path ?? "")
        components.path = (path == "") ? nil : path

        return components.URL
        }

    func alterQuery(queryMutator: [String:String?] -> [String:String?]) -> NSURL?
        {
        guard let components = NSURLComponents(URL: self, resolvingAgainstBaseURL: true) else
            { return nil }

        let queryItems = components.queryItems ?? []
        var queryDict = Dictionary<String,String?>(minimumCapacity: queryItems.count)
        for item in queryItems
            { queryDict[item.name] = item.value }

        let newItems = queryMutator(queryDict)
            .sort { $0.0 < $1.0 }   // canonicalize order to help resource URLs be unique
            .filter { $1 != nil }
            .map { NSURLQueryItem(name: $0.0, value: $0.1?.nilIfEmpty) }

        components.queryItems = newItems.isEmpty ? nil : newItems

        return components.URL
        }
    }
