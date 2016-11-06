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
    public func request(
            _ method:        RequestMethod,
            data:            Data,
            contentType:     String,
            requestMutation: @escaping RequestMutation = { _ in })
        -> Request
        {
        return request(method)
            {
            underlyingRequest in

            underlyingRequest.addValue(contentType, forHTTPHeaderField: "Content-Type")
            underlyingRequest.httpBody = data

            requestMutation(&underlyingRequest)
            }
        }

    /**
      Convenience method to initiate a request with a text body.

      If the string cannot be encoded using the given encoding, this methods triggers the `onFailure(...)` request hook
      immediately, without touching the network.

      - Parameter contentType: `text/plain` by default.
      - Parameter encoding: UTF-8 (`NSUTF8StringEncoding`) by default.
    */
    public func request(
            _ method:        RequestMethod,
            text:            String,
            contentType:     String = "text/plain",
            encoding:        String.Encoding = String.Encoding.utf8,
            requestMutation: @escaping RequestMutation = { _ in })
        -> Request
        {
        guard let rawBody = text.data(using: encoding),
              let encodingName =
                  CFStringConvertEncodingToIANACharSetName(
                      CFStringConvertNSStringEncodingToEncoding(
                          encoding.rawValue))
        else
            {
            return Resource.failedRequest(
                RequestError(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: RequestError.Cause.UnencodableText(encoding: encoding, text: text)))
            }

        return request(method, data: rawBody, contentType: "\(contentType); charset=\(encodingName)", requestMutation: requestMutation)
        }

    /**
      Convenience method to initiate a request with a JSON body.

      If the `json` cannot be encoded as JSON, e.g. if it is a dictionary with non-JSON-convertible data, this methods
      triggers the `onFailure(...)` request hook immediately, without touching the network.

      - Parameter contentType: `application/json` by default.
    */
    public func request(
            _ method:        RequestMethod,
            json:            JSONConvertible,
            contentType:     String = "application/json",
            requestMutation: @escaping RequestMutation = { _ in })
        -> Request
        {
        guard JSONSerialization.isValidJSONObject(json) else
            {
            return Resource.failedRequest(
                RequestError(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: RequestError.Cause.InvalidJSONObject()))
            }

        do  {
            let rawBody = try JSONSerialization.data(withJSONObject: json, options: [])
            return request(method, data: rawBody, contentType: contentType, requestMutation: requestMutation)
            }
        catch
            {
            // Swift doesn’t catch NSInvalidArgumentException, so the isValidJSONObject() method above is necessary
            // to handle the case of non-encodable input. Given that, it's unclear what other circumstances would cause
            // encoding to fail such that dataWithJSONObject() is declared “throws” (radar 21913397, Apple-rejected!),
            // but we catch the exception anyway instead of using try! and crashing.

            return Resource.failedRequest(
                RequestError(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: error))
            }
        }

    /**
      Convenience method to initiate a request with URL-encoded parameters in the meesage body.

      This method performs all necessary escaping, and has full Unicode support in both keys and values.

      The content type is `application/x-www-form-urlencoded`.
    */
    public func request(
            _ method:          RequestMethod,
            urlEncoded params: [String:String],
            requestMutation:   @escaping RequestMutation = { _ in })
        -> Request
        {
        func urlEscape(_ string: String) throws -> String
            {
            guard let escaped = string.addingPercentEncoding(withAllowedCharacters: Resource.allowedCharsInURLEncoding) else
                { throw RequestError.Cause.NotURLEncodable(offendingString: string) }

            return escaped
            }

        do
            {
            let paramString = try
                params.map { try urlEscape($0.0) + "=" + urlEscape($0.1) }
                      .sorted()
                      .joined(separator: "&")
            return request(method,
                data: paramString.data(using: String.Encoding.ascii)!,  // Reason for !: ASCII guaranteed safe because of escaping
                contentType: "application/x-www-form-urlencoded",
                requestMutation: requestMutation)
            }
        catch
            {
            return Resource.failedRequest(
                RequestError(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: error))
            }
        }

    private static let allowedCharsInURLEncoding: CharacterSet =
        {
        // Based on https://github.com/Alamofire/Alamofire/blob/338955a54722dea6051ed5c5c76a8736f4195515/Source/ParameterEncoding.swift#L186
        let charsToEscape = ":#[]@!$&'()*+,;="
        var allowedChars = CharacterSet.urlQueryAllowed
        allowedChars.remove(charactersIn: charsToEscape)
        return allowedChars
        }()

    /**
      Returns a request for this resource that immedately fails, without ever touching the network. Useful for creating
      your own custom requests that perform pre-request validation.
     */
    public static func failedRequest(_ error: RequestError) -> Request
        {
        return FailedRequest(error: error)
        }
    }


/// For requests that failed before they even made it to the network layer
private final class FailedRequest: RequestWithDefaultCallbacks
    {
    private let error: RequestError

    var isCompleted: Bool { return true }
    var progress: Double { return 1 }

    init(error: RequestError)
        { self.error = error }

    func addResponseCallback(_ callback: @escaping ResponseCallback) -> Self
        {
        // FailedRequest is immutable and thus threadsafe. However, this call would not be safe if this were a
        // NetworkRequest, and callers can’t assume they’re getting a FailedRequest, so we validate main thread anyway.

        DispatchQueue.mainThreadPrecondition()

        // Callback should not be called synchronously

        DispatchQueue.main.async
            { callback(ResponseInfo(response: .failure(self.error))) }

        return self
        }

    func onProgress(_ callback: @escaping (Double) -> Void) -> Self
        {
        DispatchQueue.mainThreadPrecondition()

        DispatchQueue.main.async
            { callback(1) }

        return self
        }

    func start() -> Self
        { return self }

    func cancel()
        { DispatchQueue.mainThreadPrecondition() }

    func repeated() -> Request
        { return self }
    }

/// Dictionaries and arrays can both be passed to `Resource.request(_:json:contentType:requestMutation:)`.
public protocol JSONConvertible { }
extension NSDictionary: JSONConvertible { }
extension NSArray:      JSONConvertible { }
extension Dictionary:   JSONConvertible { }
extension Array:        JSONConvertible { }
