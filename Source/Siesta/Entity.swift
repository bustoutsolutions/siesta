//
//  Entity.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/**
  An [HTTP entity](http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#). Consists of data content plus metadata about
  the content’s type and freshness.

  Typically extracted from an HTTP message body.
*/
public struct Entity<ContentType>
    {
    /**
      The data itself. When constructed from an HTTP response, it begins its life as `Data`, but may become any type
      of object after running though the service’s `ResponseTransformer` chain.

      When using `content`, because you do not know what the server actually returned, write your code to handle it
      being of an unexpected type. Siesta provides `TypedContentAccessors` to help deal with this.

      - Note:
          Siesta’s future direction is to let users declare their expected type at the resource level by asking for a
          `Resource<T>`, and have that resource report an unexpected content type from the server as a request failure.
          However, limitations of Swift’s type system currently make this unworkable. Given what the core Swift team is
          saying, we’re cautiously optimistic that Swift 4 will be able to support this.

      - SeeAlso: `TypedContentAccessors`
    */
    public var content: ContentType

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
        { return header(forKey: "etag") }

    /**
      Returns the value of the HTTP header with the given key. The key is case insensitive.

      Entity does not support multi-valued headers (i.e. headers which occur more than once in the response).

      - Parameter key: The case-insensitive header name.
    */
    public func header(forKey key: String) -> String?
        { return headers[key.lowercased()] }

    /**
      All HTTP headers sent with this entity. The keys are in lower case (and will be converted to lowercase if you
      mutate the dictionary).

      - See also: `header(forKey:)`
    */
    public var headers: [String:String]
        {
        get { return headersNormalized }
        set {
            headersNormalized = newValue.mapDict
                { ($0.lowercased(), $1) }
            }
        }

    private var headersNormalized: [String:String] = [:]

    /// The time at which this data was last known to be valid.
    public var timestamp: TimeInterval

    /**
      Extracts data from a network response.
    */
    public init(response: HTTPURLResponse?, content: ContentType)
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

      - SeeAlso: `Resource.overrideLocalData(with:)`
    */
    public init(
            content: ContentType,
            contentType: String,
            charset: String? = nil,
            headers: [String:String] = [:])
        {
        var headers = headers
        headers["Content-Type"] = contentType

        self.init(content: content, charset: charset, headers: headers)
        }

    /**
      Full-width initializer, typically used only for reinflating cached data.
    */
    public init(
            content: ContentType,
            charset: String? = nil,
            headers: [String:String],
            timestamp: TimeInterval? = nil)
        {
        self.content = content
        self.charset = charset

        if let timestamp = timestamp
            { self.timestamp = timestamp }
        else
            {
            self.timestamp = 0
            self.touch()
            }

        self.headers = headers
        }

    /// Updates `timestamp` to the current time.
    public mutating func touch()
        { timestamp = now() }

    /// Returns an identical `Entity` with `content` cast to `NewType` if the type is convertible, nil otherwise.
    public func withContentRetyped<NewType>() -> Entity<NewType>?
        {
        guard let retypedContent = content as? NewType else
            { return nil }

        return Entity<NewType>(content: retypedContent, charset: charset, headers: headers, timestamp: timestamp)
        }
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
          return typedContent(ifNone: placeholderKnob)
        }
      }

  Note that the sample code above is _only_ a convenience accessor. It checks whether the entity already has a
  `UIDoorknob`, but does not do any parsing to put a `UIDoorknob` there in the first place. You’d need to pair this with
  a custom `ResponseTransformer` that converts raw doorknob responses to `UIDoorknob`s.
*/
public protocol TypedContentAccessors
    {
    /// The type of entity content the implementing type provides. Often `Any`.
    associatedtype ContentType

    /// The entity to which the convenience accessors will apply.
    var entityForTypedContentAccessors: Entity<ContentType>? { get }
    }

public extension TypedContentAccessors
    {
    /**
      A convenience for retrieving the content in this container when you expect it to be of a specific type.
      For example, if you expect the content to be a UIImage:

          let image = resource.typedContent(ifNone: UIImage(named: "placeholder.png"))

      - Returns: The content if it is present _and_ can be downcast to a type matching both the `ifNone` parameter
                 and the inferred return type; otherwise returns `ifNone`.

      - SeeAlso: `typedContent()`
      - SeeAlso: `ResponseTransformer`
    */
    public func typedContent<T>(ifNone defaultContent: @autoclosure () -> T) -> T
        {
        return (entityForTypedContentAccessors?.content as? T) ?? defaultContent()
        }

    /// Variant of `typedContent(ifNone:)` with optional input & output.
    public func typedContent<T>(ifNone defaultContent: @autoclosure () -> T?) -> T?
        {
        return (entityForTypedContentAccessors?.content as? T) ?? defaultContent()
        }

    /**
      A variant of `typedContent(ifNone:)` that infers the desired type entirely from context, and returns nil if the
      content is either not present or cannot be cast to that type. For example:

          func showUser(_ user: User?) {
            ...
          }

          showUser(resource.typedContent())  // Infers that desired type is User
    */
    public func typedContent<T>() -> T?
        {
        return typedContent(ifNone: nil)
        }

    /// Returns content if it is a dictionary with string keys; otherwise returns an empty dictionary.
    public var jsonDict: [String:Any] { return typedContent(ifNone: [:]) }

    /// Returns content if it is an array; otherwise returns an empty array.
    public var jsonArray: [Any]       { return typedContent(ifNone: []) }

    /// Returns content if it is a string; otherwise returns an empty string.
    public var text: String           { return typedContent(ifNone: "") }
    }

extension Entity: TypedContentAccessors
    {
    /// Typed content accessors such as `.text` and `.jsonDict` apply to this entity’s content.
    public var entityForTypedContentAccessors: Entity<ContentType>? { return self }
    }

extension Resource: TypedContentAccessors
    {
    /// Typed content accessors such as `.text` and `.jsonDict` apply to `latestData?.content`.
    public var entityForTypedContentAccessors: Entity<Any>? { return latestData }
    }

extension RequestError: TypedContentAccessors
    {
    /// Typed content accessors such as `.text` and `.jsonDict` apply to `entity?.content`.
    public var entityForTypedContentAccessors: Entity<Any>? { return entity }
    }
