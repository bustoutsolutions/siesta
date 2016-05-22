//
//  ConfigurationPatternConvertible.swift
//  Siesta
//
//  Created by Paul on 2016/4/22.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation


/**
  A type that can serve as a URL matcher for service configuration.

  Siesta provides implementations of this protocol for `String` (for glob-based matching) and `Resource` (to configure
  one specific resource).

  - SeeAlso: `Service.configure(_:description:configurer:)`
  - SeeAlso: `String.configurationPattern(_:)`
  - SeeAlso: `Resource.configurationPattern(_:)`
*/
public protocol ConfigurationPatternConvertible
    {
    /// Turns the receiver into a predicate that matches URLs.
    func configurationPattern(service: Service) -> NSURL -> Bool

    /// A logging-friendly description of the receiver when it acts as a URL pattern.
    var configurationPatternDescription: String { get }
    }

/**
  Support for passing URL patterns with wildcards to `Service.configure(...)`.
*/
extension String: ConfigurationPatternConvertible
    {
    /**
      Matches URLs using shell-like wildcards / globs.

      The `urlPattern` is interpreted relative to the service’s base URL unless it begins with a protocol (e.g. `http:`).
      If it is relative, the leading slash is optional.

      The pattern supports two wildcards:

      - `*` matches zero or more characters within a path segment, and
      - `**` matches zero or more characters across path segments, with the special case that `/**/` matches `/`.

      Examples:

      - `/foo/*/bar` matches `/foo/1/bar` and  `/foo/123/bar`.
      - `/foo/**/bar` matches `/foo/bar`, `/foo/123/bar`, and `/foo/1/2/3/bar`.
      - `/foo*/bar` matches `/foo/bar` and `/food/bar`.

      The pattern ignores the resource’s query string.
    */
    public func configurationPattern(service: Service) -> NSURL -> Bool
        {
        // If the pattern has a URL protocol (e.g. "http:"), interpret it as absolute.
        // If the service has no baseURL, interpret the pattern as absolure.
        // Otherwise, interpret pattern as relative to baseURL.

        let resolvedPattern: String
        if let prefix = service.baseURL?.absoluteString where !containsRegex("^[a-z]+:")
            { resolvedPattern = prefix + stripPrefix("/") }
        else
            { resolvedPattern = self }

        let pattern = NSRegularExpression.compile(
            "^"
            + NSRegularExpression.escapedPatternForString(resolvedPattern)
                .replacingString("\\*\\*\\/", "([^:?]*/|)")
                .replacingString("\\*\\*",    "[^:?]*")
                .replacingString("\\*",       "[^/:?]*")
            + "($|\\?)")
        debugLog(.Configuration, ["URL pattern", self, "compiles to regex", pattern.pattern])

        return { pattern.matches($0.absoluteString) }
        }

    /// :nodoc:
    public var configurationPatternDescription: String
        { return self }
    }

/**
  Support for passing a specific `Resource` to `Service.configure(...)`.
*/
extension Resource: ConfigurationPatternConvertible
    {
    /**
      Matches this specific resource when passed as a pattern to `Service.configure(...)`.
    */
    public func configurationPattern(service: Service) -> NSURL -> Bool
        {
        let resourceURL = url  // prevent resource capture in closure
        return { $0 == resourceURL }
        }

    /// :nodoc:
    public var configurationPatternDescription: String
        { return url.absoluteString }
    }
