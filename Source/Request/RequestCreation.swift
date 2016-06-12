//
//  RequestCreation.swift
//  Siesta
//
//  Created by Paul on 2015/12/15.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//
import Foundation

public extension Resource
    {
    // MARK: Request Creation Conveniences

    /**
      Convenience method to initiate a request with a body containing arbitrary data.
    */
    @warn_unused_result
    public func request(
            method:      RequestMethod,
            data:        NSData,
            contentType: String,
            @noescape requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        return request(method)
            {
            nsreq in

            nsreq.addValue(contentType, forHTTPHeaderField: "Content-Type")
            nsreq.HTTPBody = data

            requestMutation(nsreq)
            }
        }

    /**
      Convenience method to initiate a request with a text body.

      If the string cannot be encoded using the given encoding, this methods triggers the `onFailure(_:)` request hook
      immediately, without touching the network.

      - Parameter contentType: `text/plain` by default.
      - Parameter encoding: UTF-8 (`NSUTF8StringEncoding`) by default.
    */
    @warn_unused_result
    public func request(
            method:      RequestMethod,
            text:        String,
            contentType: String = "text/plain",
            encoding:    NSStringEncoding = NSUTF8StringEncoding,
            @noescape requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        let encodingName = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(encoding))
        guard let rawBody = text.dataUsingEncoding(encoding) else
            {
            return Resource.failedRequest(
                Error(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: Error.Cause.UnencodableText(encodingName: encodingName as String, text: text)))
            }

        return request(method, data: rawBody, contentType: "\(contentType); charset=\(encodingName)")
        }

    /**
      Convenience method to initiate a request with a JSON body.

      If the `json` cannot be encoded as JSON, e.g. if it is a dictionary with non-JSON-convertible data, this methods
      triggers the `onFailure(_:)` request hook immediately, without touching the network.

      - Parameter contentType: `application/json` by default.
    */
    @warn_unused_result
    public func request(
            method:      RequestMethod,
            json:        NSJSONConvertible,
            contentType: String = "application/json",
            @noescape requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        guard NSJSONSerialization.isValidJSONObject(json) else
            {
            return Resource.failedRequest(
                Error(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: Error.Cause.InvalidJSONObject()))
            }

        do  {
            let rawBody = try NSJSONSerialization.dataWithJSONObject(json, options: [])
            return request(method, data: rawBody, contentType: contentType)
            }
        catch
            {
            // Swift doesn’t catch NSInvalidArgumentException, so the isValidJSONObject() method above is necessary
            // to handle the case of non-encodable input. Given that, it's unclear what other circumstances would cause
            // encoding to fail such that dataWithJSONObject() is declared “throws” (radar 21913397, Apple-rejected!),
            // but we catch the exception anyway instead of using try! and crashing.

            return Resource.failedRequest(
                Error(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: error))
            }
        }

    /**
      Convenience method to initiate a request with URL-encoded parameters in the meesage body.

      This method performs all necessary escaping, and has full Unicode support in both keys and values.

      The content type is `application/x-www-form-urlencoded`.
    */
    @warn_unused_result
    public func request(
            method:            RequestMethod,
            urlEncoded params: [String:String],
            requestMutation:   NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        func urlEscape(string: String) throws -> String
            {
            guard let escaped = string.stringByAddingPercentEncodingWithAllowedCharacters(Resource.allowedCharsInURLEncoding) else
                { throw Error.Cause.NotURLEncodable(offendingString: string) }

            return escaped
            }

        do
            {
            let paramString = try
                params.map { try urlEscape($0.0) + "=" + urlEscape($0.1) }
                      .sort()
                      .joinWithSeparator("&")
            return request(method,
                data: paramString.dataUsingEncoding(NSASCIIStringEncoding)!,  // Reason for !: ASCII guaranteed safe because of escaping
                contentType: "application/x-www-form-urlencoded")
            }
        catch
            {
            return Resource.failedRequest(
                Error(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: error))
            }
        }

    private static let allowedCharsInURLEncoding: NSCharacterSet =
        {
        // Based on https://github.com/Alamofire/Alamofire/blob/338955a54722dea6051ed5c5c76a8736f4195515/Source/ParameterEncoding.swift#L186
        let charsToEscape = ":#[]@!$&'()*+,;="
        let allowedChars = NSCharacterSet.URLQueryAllowedCharacterSet().mutableCopy()
                           as! NSMutableCharacterSet  // Reason for !: No typesafe NSMutableCharacterSet copy constructor
        allowedChars.removeCharactersInString(charsToEscape)
        return allowedChars
        }()

    /**
      Returns a request for this resource that immedately fails, without ever touching the network. Useful for creating
      your own custom requests that perform pre-request validation.
     */
    public static func failedRequest(error: Error) -> Request
        {
        return FailedRequest(error: error)
        }
    }


/// For requests that failed before they even made it to the network layer
private final class FailedRequest: RequestWithDefaultCallbacks
    {
    private let error: Error

    var isCompleted: Bool { return true }
    var progress: Double { return 1 }

    init(error: Error)
        { self.error = error }

    func addResponseCallback(callback: ResponseCallback)
        {
        // FailedRequest is immutable and thus threadsafe. However, this call would not be safe if this were a
        // NetworkRequest, and callers can’t assume they’re getting a FailedRequest, so we validate main thread anyway.

        dispatch_assert_main_queue()

        // Callback should not be called synchronously

        dispatch_async(dispatch_get_main_queue())
            { callback((.Failure(self.error), isNew: true)) }
        }

    func onProgress(callback: Double -> Void) -> Self
        {
        dispatch_assert_main_queue()

        dispatch_async(dispatch_get_main_queue())
            { callback(1) }

        return self
        }

    func cancel()
        { dispatch_assert_main_queue() }
    }
