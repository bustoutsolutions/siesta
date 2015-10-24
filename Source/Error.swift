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
  even mutually exclusive: Siesta errors do not break cleanly into HTTP-based vs. exception/NSError-based, for example,
  because network implementations may sometimes provide _both_ an underlying NSError _and_ an HTTP diagnostic.
  
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
            cause: ErrorType,
            entity: Entity? = nil)
        {
        self.userMessage = userMessage
        self.cause = cause
        self.entity = entity
        }
    
    public var isCancellation: Bool
        {
        guard let cause = cause else
            { return false }
        guard case Error.Cause.RequestCancelled = cause else
            { return false }
        return true
        }
    }

public extension Error
    {
    /**
      Underlying causes of errors reported by Siesta. You will find these on the `Error.cause` property.
      
      Note that `Error.cause` may contain errors from the underlying network library that do not appear in this enum.
      
      Client code rarely needs to use these values, but they can be useful if you want to add special handling for
      specific errors. For example, if you’re working with an API that can return a 200 with an empty response, then
      (1) gee, that’s weird, and (2) you can turn that “empty response” error into a success by adding a transformer:
      
          configure {
            $0.config.responseTransformers.add(EmptyResponseHandler())
          }
          
          ...
    
          struct EmptyResponseHandler: ResponseTransformer {
            func process(response: Response) -> Response {
              switch response {
                case .Success:
                  return response
                  
                case .Failure(let error):
                  guard let cause = error.cause else {
                    return response
                  }
                  guard case Siesta.Error.Cause.EmptyResponse = cause else {
                    return response
                  }
                  return .Success(Entity(
                    content: "Nothingness. Tumbleweeds. The Void.",
                    contentType: "text/string"))
              }
            }
          }
    */
    public enum Cause: ErrorType
        {
        // MARK: Request Errors
        
        /// Unable to create a text request with the requested character encoding.
        case UnencodableText(encodingName: String, text: String)
        
        /// Unable to create a JSON request using an object that is not JSON-encodable.
        case InvalidJSONObject
        
        /// Unable to create a URL-encoded request, probably due to unpaired Unicode surrogate chars.
        case NotURLEncodable(offendingString: String)
        
        // MARK: Network Errors
        
        /// Underlying network request was cancelled before response arrived.
        case RequestCancelled(networkError: ErrorType?)
        
        // TODO: Consider explicitly detecting offline connection
        
        // MARK: Response Errors
        
        /// Server unexpectly returned an empty response body on success.
        case EmptyResponse
        
        /// Server sent 304 (“not changed”), but we have no local data for the resource.
        case NoLocalDataFor304
        
        /// The server sent a text encoding name that the OS does not recognize.
        case InvalidTextEncoding(encodingName: String)
        
        /// The server’s response could not be decoded using the text encoding it specified.
        case UndecodableText(encodingName: String)
        
        /// Siesta’s default JSON parser accepts only dictionaries and arrays, but the server
        /// sent a response containing a bare JSON primitive.
        case JSONResponseIsNotDictionaryOrArray
        
        /// The server’s response could not be decoded using the text encoding it specified.
        case UndecodableImage
        
        /// Response transformer received entity content from upstream of a type it doesn’t know how to process.
        case WrongTypeInTranformerPipeline(
            expected: String,  // TODO: Does Swift allow something more inspectable than String? Any.Type & similar don't seem to work.
            actual: String,
            transformer: ResponseTransformer)
        }
    }
