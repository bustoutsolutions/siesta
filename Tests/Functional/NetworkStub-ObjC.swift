//
//  NetworkStub-ObjC.swift
//  Siesta
//
//  Created by Paul on 2020/3/26.
//  Copyright © 2020 Bust Out Solutions. All rights reserved.
//

// swiftlint:disable function_parameter_count missing_docs

import Siesta

import Foundation

extension NetworkStub
    {
    @objc
    public static func add(
            forMethod method: String,
            resource: Resource,
            returningStatusCode status: Int)
        {
        add(forMethod: method, resource: resource, headers: [:], body: nil, returningStatusCode: status)
        }

    @objc
    public static func add(
            forMethod method: String,
            resource: Resource,
            headers requestHeaders: [String:String],
            body requestBody: String?,
            returningStatusCode status: Int)
        {
        add(forMethod: method, resource: resource, headers: requestHeaders, body: requestBody,
            returningStatusCode: status, headers: [:], body: nil)
        }

    @objc
    public static func add(
            forMethod method: String,
            resource: Resource,
            returningStatusCode status: Int,
            headers responseHeaders: [String:String],
            body responseBody: String?)
        {
        add(forMethod: method, resource: resource, headers: [:], body: nil,
            returningStatusCode: status, headers: responseHeaders, body: responseBody)
        }

    @objc
    public static func add(
            forMethod method: String,
            resource: Resource,
            headers requestHeaders: [String:String],
            body requestBody: String?,
            returningStatusCode status: Int,
            headers responseHeaders: [String:String],
            body responseBody: String?)
        {
        add(
            matching: RequestPattern(
                RequestMethod(rawValue: method.lowercased())!,
                { resource },
                headers: requestHeaders,
                body: requestBody),
            returning: HTTPResponse(
                status: status,
                headers: responseHeaders,
                body: responseBody))
        }
    }
