//
//  RequestCreation.swift
//  Siesta
//
//  Created by Paul on 2015/12/15.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//
import Foundation

extension Resource
    {
    // MARK: Request Creation Conveniences

    /**
      Convenience method to initiate a request with a body containing arbitrary data.
      - Parameter method: The HTTP method of the request.
      - Parameter data: The body of the request.
      - Parameter contentType: The value for the request’s `Content-Type` header. The priority order is as follows:
          - any content-type set in `Configuration.mutateRequests(...)` overrides
          - any content-type set in `requestMutation`, which overrides
          - this parameter, which overrides
          - any content-type set with `Configuration.headers`.
      - Parameter requestMutation: Allows you to override details fo the HTTP request before it is sent.
          See `request(_:requestMutation:)`.
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

            underlyingRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
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
                returning: RequestError(
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
                returning: RequestError(
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
                returning: RequestError(
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
                data: paramString.data(using: String.Encoding.ascii)
                    .forceUnwrapped(because: "URL-escaped strings are always ASCII-representable"),
                contentType: "application/x-www-form-urlencoded",
                requestMutation: requestMutation)
            }
        catch
            {
            return Resource.failedRequest(
                returning: RequestError(
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
    }

/// Dictionaries and arrays can both be passed to `Resource.request(_:json:contentType:requestMutation:)`.
public protocol JSONConvertible { }
extension NSDictionary: JSONConvertible { }
extension NSArray:      JSONConvertible { }
extension Dictionary:   JSONConvertible { }
extension Array:        JSONConvertible { }
