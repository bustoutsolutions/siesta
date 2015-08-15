//
//  ResourceData.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

/**
  Information about a resource’s state. Consists of a data payload plus metadata about the data’s type and freshness.

  Typically extracted from an HTTP message body.
*/
public struct ResourceData
    {
    /**
      The data itself. When constructed from an HTTP response, it begins its life as `NSData`, but may become any type
      of object after running though the service’s `ResponseTransformer` chain.
      
      Why is the type of this property `AnyObject` instead of a generic `T`? Because a `<T>` declaration would mean
      “Siesta guarantees the data is of type `T`” — that’s what strong static types do — but there is no way to tell
      Swift at _compile time_ what content type a server will actually send at _runtime_.
      
      The best client code can do is to say, “I expect the server to have returned data of type `T`; did it?” That is
      exactly what Swift’s `as?` operator does — and any scheme involving a generic `<T>` ends up being an obfuscated
      equivalent to `as?` — or, far worse, an obfuscated `as!`, a.k.a. “The Amazing Server-Triggered Client
      Crash-o-Matic.”
      
      In short, when using `payload`, write your code to handle the payload being of an unexpected type.
      
      - SeeAlso: `Resource.typedData(_:)`
    */
    public var payload: AnyObject
    
    /**
      The type of data contained in the payload.
      
      If the payload was parsed into a data structure, this property typically contains the type of the original raw
      data. For example, the type might be `application/json` even though `payload` is a `Dictionary` and no longer the
      original JSON text data.
      
      This property may include MIME parameters, so beware of using exact string matches. For a plain text response,
      for example, you might see “`text/plain`”, “`text/plain; charset=utf-8`”, or even “`text/foo+plain`”.
    */
    public var mimeType: String
    
    /**
      The charset given with the content type, if any.
    */
    public var charset: String?

    /**
      The etag of this data. If non-nil, Siesta will send an `If-modified-since` header with subsequent loads.
    */
    public var etag: String?

    internal var headers: [String:String]
    
    /// The time at which this data was last known to be valid.
    public private(set) var timestamp: NSTimeInterval = 0
    
    private init(
            payload: AnyObject,
            charset: String? = nil,
            headers rawHeaders: [String:String])
        {
        self.payload = payload
        
        self.headers = rawHeaders.mapDict { ($0.lowercaseString, $1) }
        
        self.mimeType = headers["content-type"] ?? "application/octet-stream"
        self.charset = charset
        self.etag = headers["etag"]
        
        self.timestamp = 0
        self.touch()
        }
    
    /**
      Extracts data from a network response.
    */
    public init(_ response: NSHTTPURLResponse?, _ payload: AnyObject)
        {
        let headers = (response?.allHeaderFields ?? [:])
            .flatMapDict { ($0 as? String, $1 as? String) }
        
        self.init(
            payload: payload,
            charset: response?.textEncodingName,
            headers: headers)
        }
    
    /**
      For creating ad hoc data locally.
      
      - SeeAlso: `Resource.localDataOverride(_:)`
    */
    public init(
            payload: AnyObject,
            mimeType: String,
            charset: String? = nil,
            var headers: [String:String] = [:])
        {
        headers["Content-Type"] = mimeType
        
        self.init(payload:payload, charset:charset, headers:headers)
        }
    
    /**
      Returns the value of the HTTP header with the given key.
      
      ResourceData does not support multi-valued headers (i.e. headers which occur more than once in the response).
      
      - Parameter key: The case-insensitive header name.
    */
    public func header(key: String) -> String?
        { return headers[key.lowercaseString] }
    
    /// Updates `timestamp` to the current time.
    public mutating func touch()
        { timestamp = now() }
    }


/**
  Provides convenience accessors
*/
public protocol DataContainer
    {
    var data: AnyObject? { get }
    }

public extension DataContainer
    {
    /**
      A convenience for retrieving the data in this container when you expect it to be of a specific type.
      Returns `latestData?.payload` if the payload can be downcast to the same type as `blankValue`;
      otherwise returns `blankValue`.
     
      For example, if you expect the resource data to be a UIImage:
     
          let image = typedData(UIImage(named: "placeholder.png"))
     
      - SeeAlso: `ResponseTransformer`
    */
    public func typedData<T>(blankValue: T) -> T
        {
        return (data as? T) ?? blankValue
        }
    
    /// Returns data if it is a dictionary with string keys; otherwise returns an empty dictionary.
    public var dict:  [String:AnyObject] { return typedData([:]) }
    
    /// Returns data if it is an array; otherwise returns an empty array.
    public var array: [AnyObject]        { return typedData([]) }

    /// Returns data if it is a string; otherwise returns an empty string.
    public var text:  String             { return typedData("") }
    }

extension Resource: DataContainer
    {
    public var data: AnyObject? { return latestData?.payload }
    }

extension ResourceData: DataContainer
    {
    public var data: AnyObject? { return payload }
    }

extension ResourceError: DataContainer
    {
    public var data: AnyObject? { return entity?.payload }
    }
