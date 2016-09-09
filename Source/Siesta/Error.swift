//
//  Error.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/**
  Information about a failed resource request.

  Siesta can encounter errors from many possible sources, including:

  - client-side encoding / request creation issues,
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

    /// Details about the underlying error. Errors originating from Siesta will have a cause from `Error.Cause`.
    /// Errors originating from the `NetworkingProvider` or custom `ResponseTransformer`s have domain-specific causes.
    public var cause: ErrorType?

    /// The time at which the error occurred.
    public let timestamp: NSTimeInterval = now()

    /**
      Initializes the error using a network response.

      If the `userMessage` parameter is nil, this initializer uses `error` or the response’s status code to generate
      a user message. That failing, it gives a generic failure message.
    */
    public init(
            response: NSHTTPURLResponse?,
            content: AnyObject?,
            cause: ErrorType?,
            userMessage: String? = nil)
        {
        self.httpStatusCode = response?.statusCode
        self.cause = cause

        if let content = content
            { self.entity = Entity(response: response, content: content) }

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
    }

public extension Error
    {
    /**
      Underlying causes of errors reported by Siesta. You will find these on the `Error.cause` property.
      (Note that `cause` may also contain errors from the underlying network library that do not appear here.)

      The primary purpose of these error causes is to aid debugging. Client code rarely needs to work with them,
      but they can be useful if you want to add special handling for specific errors.

      For example, if you’re working with an API that sometimes returns garbled text data that isn’t decodable,
      and you want to show users a placeholder message instead of an error, then (1) gee, that’s weird, and
      (2) you can turn that one specific error into a success by adding a transformer:

          configure {
            $0.config.responseTransformers.add(GarbledResponseHandler())
          }

          ...

          struct GarbledResponseHandler: ResponseTransformer {
            func process(response: Response) -> Response {
              switch response {
                case .Success:
                  return response

                case .Failure(let error):
                  if error.cause is Siesta.Error.Cause.InvalidTextEncoding {
                    return .Success(Entity(
                      content: "Nothingness. Tumbleweeds. The Void.",
                      contentType: "text/string"))
                  } else {
                    return response
                  }
              }
            }
          }
    */
    public enum Cause
        {
        // MARK: Request Errors

        /// Unable to create a text request with the requested character encoding.
        public struct UnencodableText: ErrorType
            {
            public let encodingName: String
            public let text: String
            }

        /// Unable to create a JSON request using an object that is not JSON-encodable.
        public struct InvalidJSONObject: ErrorType { }

        /// Unable to create a URL-encoded request, probably due to unpaired Unicode surrogate chars.
        public struct NotURLEncodable: ErrorType
            {
            public let offendingString: String
            }

        // MARK: Network Errors

        /// Underlying network request was cancelled before response arrived.
        public struct RequestCancelled: ErrorType
            {
            public let networkError: ErrorType?
            }

        // TODO: Consider explicitly detecting offline connection

        // MARK: Response Errors

        /// Server sent 304 (“not changed”), but we have no local data for the resource.
        public struct NoLocalDataFor304: ErrorType { }

        /// The server sent a text encoding name that the OS does not recognize.
        public struct InvalidTextEncoding: ErrorType
            {
            public let encodingName: String
            }

        /// The server’s response could not be decoded using the text encoding it specified.
        public struct UndecodableText: ErrorType
            {
            public let encodingName: String
            }

        /// Siesta’s default JSON parser accepts only dictionaries and arrays, but the server
        /// sent a response containing a bare JSON primitive.
        public struct JSONResponseIsNotDictionaryOrArray: ErrorType
            {
            public let actualType: String
            }

        /// The server’s response could not be parsed using any known image format.
        public struct UnparsableImage: ErrorType { }

        /// A response transformer received entity content of a type it doesn’t know how to process. This error means
        /// that the upstream transformations may have succeeded, but did not return a value of the type the next
        /// transformer expected.
        public struct WrongInputTypeInTranformerPipeline: ErrorType
            {
            public let expectedType, actualType: String  // TODO: Does Swift allow something more inspectable than String? Any.Type & similar don't seem to work.
            public let transformer: ResponseTransformer
            }

        /// A `ResponseContentTransformer` or a closure passed to `Service.configureTransformer(...)` returned nil.
        public struct TransformerReturnedNil: ErrorType
            {
            public let transformer: ResponseTransformer
            }
        }
    }
