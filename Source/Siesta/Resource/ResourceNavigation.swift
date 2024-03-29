//
//  ResourceNavigation.swift
//  Siesta
//
//  Created by Paul on 2016/8/16.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

extension Resource
    {
    // MARK: URL navigation

    /**
      Returns the resource with the given string appended to the path of this resource’s URL, with a joining slash
      inserted if necessary.

      Use this method for hierarchical resource navigation. The typical use case is constructing a resource URL from
      path components and IDs:

          let resource = service.resource("/widgets")
          resource.child("123").child("details")
            //→ /widgets/123/details

      This method _always_ returns a subpath of the receiving resource. It does not apply any special
      interpretation to strings such `./`, `//` or `?` that have significance in other URL-related
      situations. Special characters are escaped when necessary, and otherwise ignored. See
      [`ResourcePathsSpec`](https://bustoutsolutions.github.io/siesta/specs/#ResourcePathsSpec)
      for details.

      - SeeAlso: `relative(_:)`
    */
    @objc
    public func child(_ subpath: String) -> Resource
        {
        service.resource(absoluteURL: url.appendingPathComponent(subpath))
        }

    /**
      Returns the resource with the given URL, using this resource’s URL as the base if it is a relative URL.

      This method interprets strings such as `.`, `..`, and a leading `/` or `//` as relative URLs. It resolves its
      parameter much like an `href` attribute in an HTML document. Refer to
      [`ResourcePathsSpec`](https://bustoutsolutions.github.io/siesta/specs/#ResourcePathsSpec)
      for details.

      - SeeAlso:
        - `optionalRelative(_:)`
        - `child(_:)`
    */
    @objc
    public func relative(_ href: String) -> Resource
        {
        service.resource(absoluteURL: URL(string: href, relativeTo: url))
        }

    /**
      Returns `relative(href)` if `href` is present, and nil if `href` is nil.

      This convenience method is useful for resolving URLs returned as part of a JSON response body:

          let href = resource.jsonDict["owner"] as? String  // href is an optional
          if let ownerResource = resource.optionalRelative(href) {
            ...
          }
    */
    @objc
    public func optionalRelative(_ href: String?) -> Resource?
        {
        if let href = href
            { return relative(href) }
        else
            { return nil }
        }

    /**
      Returns this resource with the given parameter added to or changed in the query string.

      If `value` is an empty string, the parameter appears in the query string with no value (e.g. `?foo`).

      If `value` is nil, however, the parameter is removed.

      There is no support for parameters with an equal sign but an empty value (e.g. `?foo=`).
      There is also no support for repeated keys in the query string (e.g. `?foo=1&foo=2`).
      If you need to circumvent either of these restrictions, you can create the query string yourself and pass it to
      `relative(_:)` instead of using this method. For example:

          resource.relative("?foo=1&foo=2")

      - Note: `Service` gives out unique `Resource` instances according to the full URL in string form, and thus
        considers query string parameter order significant. Therefore, to ensure that you get the same `Resource`
        instance no matter the order in which you specify parameters, `withParam(_:_:)` sorts _all_ parameters by name,
        including existing ones. Note that _only_ `withParam(_:_:)` and `withParams(_:)` do this sorting; if you use
        other methods to create query strings, it is up to you to canonicalize your parameter order.

      - SeeAlso: `withParams(_:)`
    */
    @objc(withParam:value:)
    public func withParam(_ name: String, _ value: String?) -> Resource
        {
        withParams([name: value])
        }

    /**
      Returns this resource with all the entries in the given dictionary added to or changed in the query string.
      Equivalent to chained calls to `withParam(_:_:)` using each key-value pair in the dictionary.

      See `withParam(_:_:)` for information about the meaning of nil values and empty strings, multi-values params,
      and canonical parameter ordering.
    */
    public func withParams(_ params: [String:String?]) -> Resource
        {
        service.resource(absoluteURL:
            url.alterQuery
                {
                for (name,value) in params
                    { $0[name] = value }
                })
        }
    }
