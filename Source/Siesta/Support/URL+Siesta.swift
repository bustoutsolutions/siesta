//
//  URL+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/7/17.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/// Allows interchangeable use of `String` and `URL` in calls that need a URL.
public protocol URLConvertible
    {
    /// The URL represented by this value.
    var url: URL? { get }
    }

extension String: URLConvertible
    {
    /// Returns the URL represented by this string, if it is a valid URL.
    public var url: URL?
        { return URL(string: self) }
    }

extension URL: URLConvertible
    {
    /// Returns self.
    public var url: URL?
        { return self }
    }

internal extension URL
    {
    func alterPath(_ pathMutator: (inout String) -> Void) -> URL?
        {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else
            { return nil }

        pathMutator(&components.path)

        return components.url
        }

    func alterQuery(_ queryMutator: (inout [String:String?]) -> Void) -> URL?
        {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else
            { return nil }

        let queryItems = components.queryItems ?? []
        var queryDict = [String:String?](minimumCapacity: queryItems.count)
        for item in queryItems
            { queryDict[item.name] = item.value ?? "" }

        queryMutator(&queryDict)

        let newItems = queryDict
            .sorted { $0.0 < $1.0 }   // canonicalize order to help resource URLs be unique
            .filter { $1 != nil }
            .map { URLQueryItem(name: $0.0, value: $0.1?.nilIfEmpty) }

        components.queryItems = newItems.isEmpty ? nil : newItems

        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")

        return components.url
        }
    }
