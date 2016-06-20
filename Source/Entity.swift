//
//  Entity.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/**
  An [HTTP entity](http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html). Consists of data content plus metadata about
  the content’s type and freshness.

  Typically extracted from an HTTP message body.
*/
public struct Entity
    {
    /**
      The data itself. When constructed from an HTTP response, it begins its life as `NSData`, but may become any type
      of object after running though the service’s `ResponseTransformer` chain.

      When using `content`, because you do not know what the server actually returned, write your code to handle it
      being of an unexpected type. Siesta provides `TypedContentAccessors` to help deal with this.

      - Note:
          Why is the type of this property `Any` instead of a generic `T`? Because an `Entity<T>` declaration would mean
          “Siesta guarantees the data is of type `T`” — that’s what strong static types do — but there is no way to tell
          Swift at _compile time_ what content type a server will actually send at _runtime_.

          The best client code can do is to say, “I expect the server to have returned data of type `T`; did it?” That
          is exactly what Swift’s `as?` operator does — and any scheme within the current system involving a generic
          `Entity<T>` ends up being an obfuscated equivalent to `as?` — or, far worse, an obfuscated `as!`, a.k.a.
          “The Amazing Server-Triggered Client Crash-o-Matic.”

          Siesta’s future direction is to let users declare their expected type at the resource level by asking for a
          `Resource<T>`, and have that resource report an unexpected content type from the server as a request failure.
          However, limitations of Swift’s type system currently make this unworkable. Given what the core Swift team is
          saying, we’re cautiously optimistic that Swift 3 will be able to support this.

      - SeeAlso: `TypedContentAccessors`
    */
    public var content: Any

    /**
      The type of data contained in the content.

      If the content was parsed into a data structure, this property typically contains the type of the original raw
      data. For example, the type might be `application/json` even though `content` is a `Dictionary` and no longer the
      original JSON text data.

      This property may include MIME parameters, so beware of using exact string matches. For a plain text response,
      for example, you might see “`text/plain`”, “`text/plain; charset=utf-8`”, or even “`text/foo+plain`”.
    */
    public var contentType: String
        { return headers["content-type"] ?? "application/octet-stream" }

    /**
      The charset given with the content type, if any.
    */
    public var charset: String?

    /**
      The etag of this data. If non-nil, Siesta will send an `If-None-Match` header with subsequent loads.
    */
    public var etag: String?
        { return headers["etag"] }

    internal var headers: [String:String]

    /// The time at which this data was last known to be valid.
    public var timestamp: NSTimeInterval

    /**
      Extracts data from a network response.
    */
    public init(response: NSHTTPURLResponse?, content: Any)
        {
        let headers = (response?.allHeaderFields ?? [:])
            .flatMapDict { ($0 as? String, $1 as? String) }

        self.init(
            content: content,
            charset: response?.textEncodingName,
            headers: headers)
        }

    /**
      For creating ad hoc data locally.

      - SeeAlso: `Resource.overrideLocalData(_:)`
    */
    public init(
            content: Any,
            contentType: String,
            charset: String? = nil,
            headers: [String:String] = [:])
        {
        var headers = headers
        headers["Content-Type"] = contentType

        self.init(content:content, charset:charset, headers:headers)
        }

    /**
      Full-width initializer, typically used only for reinflating cached data.
    */
    public init(
            content: Any,
            charset: String? = nil,
            headers rawHeaders: [String:String],
            timestamp: NSTimeInterval? = nil)
        {
        self.content = content
        self.headers = rawHeaders.mapDict { ($0.lowercaseString, $1) }
        self.charset = charset

        if let timestamp = timestamp
            { self.timestamp = timestamp }
        else
            {
            self.timestamp = 0
            self.touch()
            }
        }

    /**
      Returns the value of the HTTP header with the given key.

      Entity does not support multi-valued headers (i.e. headers which occur more than once in the response).

      - Parameter key: The case-insensitive header name.
    */
    @warn_unused_result
    public func header(key: String) -> String?
        { return headers[key.lowercaseString] }

    /// Updates `timestamp` to the current time.
    public mutating func touch()
        { timestamp = now() }
    }


/**
  Mixin that provides convenience accessors for the content of an optional contained entity.

  Allows you to replace the following:

      resource.latestData?.content as? String
      (resource.latestError?.entity?.content as? [String:AnyObject])?["error.detail"]

  …with:

      resource.text
      resource.latestError?.jsonDict["error.detail"]

  You can extend this protocol to provide your own convenience accessors. For example:

      extension TypedContentAccessors {
        var doorknob: UIDoorknob {
          return typedContent(ifNone: placeholderKnob))
        }
      }

  Note that the sample code above is _only_ a convenience accessor. It checks whether the entity already has a
  `UIDoorknob`, but does not do any parsing to put a `UIDoorknob` there in the first place. You’d need to pair this with
  a custom `ResponseTransformer` that converts raw doorknob responses to `UIDoorknob`s.
*/
public protocol TypedContentAccessors
    {
    /// The entity to which the convenience accessors will apply.
    var entityForTypedContentAccessors: Entity? { get }
    }

public extension TypedContentAccessors
    {
    /**
      A convenience for retrieving the content in this container when you expect it to be of a specific type.
      For example, if you expect the content to be a UIImage:

          let image = typedContent(ifNone: UIImage(named: "placeholder.png"))

      - Returns: The content if it is present _and_ can be downcast to a type matching both the `ifNone` parameter
                 and the inferred return type; otherwise returns `ifNone`.

      - SeeAlso: `typedContent()`
      - SeeAlso: `ResponseTransformer`
    */
    @warn_unused_result
    public func typedContent<T>(@autoclosure ifNone defaultContent: () -> T) -> T
        {
        return (entityForTypedContentAccessors?.content as? T) ?? defaultContent()
        }

    /// Variant of `typedContent(ifNone:)` with optional input & output.
    @warn_unused_result
    public func typedContent<T>(@autoclosure ifNone defaultContent: () -> T?) -> T?
        {
        return (entityForTypedContentAccessors?.content as? T) ?? defaultContent()
        }

    /**
      A variant of `typedContent(ifNone:)` that infers the desired type entirely from context, and returns nil if the
      content is either not present or cannot be cast to that type. For example:

          func showUser(user: User?) {
            ...
          }

          showUser(resource.typedContent())  // Infers that desired type is User
    */
    @warn_unused_result
    public func typedContent<T>() -> T?
        {
        return typedContent(ifNone: nil)
        }

    /// Returns content if it is a dictionary with string keys; otherwise returns an empty dictionary.
    public var jsonDict: [String:AnyObject] { return typedContent(ifNone: [:]) }

    /// Returns content if it is an array; otherwise returns an empty array.
    public var jsonArray: [AnyObject]       { return typedContent(ifNone: []) }

    /// Returns content if it is a string; otherwise returns an empty string.
    public var text: String                 { return typedContent(ifNone: "") }
    }

extension Entity: TypedContentAccessors
    {
    /// Typed content accessors such as `.text` and `.jsonDict` apply to this entity’s content.
    public var entityForTypedContentAccessors: Entity? { return self }
    }

extension Resource: TypedContentAccessors
    {
    /// Typed content accessors such as `.text` and `.jsonDict` apply to `latestData?.content`.
    public var entityForTypedContentAccessors: Entity? { return latestData }
    }

extension Error: TypedContentAccessors
    {
    /// Typed content accessors such as `.text` and `.jsonDict` apply to `entity?.content`.
    public var entityForTypedContentAccessors: Entity? { return entity }
    }
