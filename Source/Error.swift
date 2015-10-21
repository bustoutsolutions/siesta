//
//  Error.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

/**
  Information about a failed resource request.
  
  Siesta can encounter errors from many possible sources, including:
  
  - client-side parse issues,
  - network connectivity problems,
  - protocol issues (e.g. certificate problems),
  - server errors (404, 500, etc.), and
  - client-side parsing and entity validation failures.
  
  `Error` presents all these errors in a uniform structure. Several properties preserve diagnostic information,
  which you can use to intercept specific known errors, but these diagnostic properties are all optional. They are not
  even mutually exclusive: Siesta errors do not break cleanly into HTTP-based vs. NSError-based, for example, because
  network implementations may sometimes provide _both_ an underlying NSError _and_ an HTTP diagnostic.

  The one ironclad guarantee that `Error` makes is the presence of a `userMessage`.
*/
public struct Error: ErrorType
    {
    /**
      A description of this error suitable for showing to the user. Typically messages are brief and in plain language,
      e.g. “Not found,” “Invalid username or password,” or “The internet connection is offline.”
    */
    public var userMessage: String

    /// The HTTP status code (e.g. 404) if this error came from an HTTP response.
    public var httpStatusCode: Int?
    
    /// The response body if this error came from an HTTP response. Its meaning is API-specific.
    public var entity: Entity?
    
    /// Details about the underlying error.
    public var cause: ErrorType?
    
    /// The time at which the error occurred.
    public let timestamp: NSTimeInterval = now()
    
    /**
      Initializes the error using a network response.

      If the `userMessage` parameter is nil, this initializer uses `error` or the response’s status code to generate
      a user message. That failing, it gives a generic failure message.
    */
    public init(
            _ response: NSHTTPURLResponse?,
            _ content: AnyObject?,
            _ cause: ErrorType?,
            userMessage: String? = nil)
        {
        self.httpStatusCode = response?.statusCode
        self.cause = cause
        
        if let content = content
            { self.entity = Entity(response, content) }
        
        if let message = userMessage
            { self.userMessage = message }
        else if let message = (cause as? NSError)?.localizedDescription
            { self.userMessage = message }
        else if let code = self.httpStatusCode
            { self.userMessage = NSHTTPURLResponse.localizedStringForStatusCode(code).capitalizedFirstCharacter }
        else
            { self.userMessage = NSLocalizedString("Request failed", comment: "userMessage") }   // Is this reachable?
        }
    
    /**
        Initializes the error using an underlying error.
    */
    public init(
            userMessage: String,
            cause: ErrorType? = nil,
            entity: Entity? = nil)
        {
        self.userMessage = userMessage
        self.cause = cause
        self.entity = entity
        }

    /**
        Convenience to create a custom error with an user & debug messages. The `debugMessage` parameter is
        wrapped in the `cause` property as an `NSError`.
    */
    public init(
            userMessage: String,
            debugMessage: String,
            entity: Entity? = nil)
        {
        let nserror = NSError(domain: "Siesta", code: -1, userInfo: [NSLocalizedDescriptionKey: debugMessage])
        self.init(userMessage: userMessage, cause: nserror, entity: entity)
        }
    
    /// True if this error represents a cancelled request
    public var isCancellation: Bool
        {
        guard let nsError = cause as? NSError else
            { return false }
        
        return nsError.domain == NSURLErrorDomain
            && nsError.code == NSURLErrorCancelled
        }
    }
