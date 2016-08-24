//
//  NSURL+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/7/17.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/// Allows interchangeable use of `String` and `NSURL` in calls that need a URL.
public protocol URLConvertible
    {
    /// The URL represented by this value.
    var url: NSURL? { get }
    }

extension String: URLConvertible
    {
    /// Returns the URL represented by this string, if it is a valid URL.
    public var url: NSURL?
        { return NSURL(string: self) }
    }

extension NSURL: URLConvertible
    {
    /// Returns self.
    public var url: NSURL?
        { return self }
    }

internal extension NSURL
    {
    @warn_unused_result
    func alterPath(@noescape pathMutator: String -> String) -> NSURL?
        {
        guard let components = NSURLComponents(URL: self, resolvingAgainstBaseURL: true) else
            { return nil }

        let path = pathMutator(components.path ?? "")
        components.path = (path == "") ? nil : path

        return components.URL
        }

    @warn_unused_result
    func alterQuery(@noescape queryMutator: [String:String?] -> [String:String?]) -> NSURL?
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

        components.percentEncodedQuery = components.percentEncodedQuery?
            .stringByReplacingOccurrencesOfString("+", withString: "%2B")

        return components.URL
        }
    }
