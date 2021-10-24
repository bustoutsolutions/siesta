//
//  NetworkRequest.swift
//  Siesta
//
//  Created by Paul on 2015/12/15.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

internal final class NetworkRequestDelegate: RequestDelegate
    {
    // Basic metadata
    private let resource: Resource
    private let method: RequestMethod
    internal var config: Configuration
        { resource.configuration(for: method) }
    internal let requestDescription: String

    // Networking
    private let requestBuilder: () -> URLRequest      // so repeated() can re-read config
    private let underlyingRequest: URLRequest
    internal var networking: RequestNetworking?       // present only after start()

    // Progress
    private var progressComputation: RequestProgressComputation

    // MARK: Managing request

    init(resource: Resource, requestBuilder: @escaping () -> URLRequest)
        {
        self.resource = resource
        self.requestBuilder = requestBuilder
        underlyingRequest = requestBuilder()

        method = RequestMethod(rawValue: underlyingRequest.httpMethod?.lowercased() ?? "")
            ?? .get  // All unrecognized methods default to .get

        requestDescription =
            SiestaLog.Category.enabled.contains(.network) || SiestaLog.Category.enabled.contains(.networkDetails)
                ? debugStr([underlyingRequest.httpMethod, underlyingRequest.url])
                : "NetworkRequest"

        progressComputation = RequestProgressComputation(isGet: underlyingRequest.httpMethod == "GET")
        }

    func startUnderlyingOperation(passingResponseTo completionHandler: RequestCompletionHandler)
        {
        let networking = resource.service.networkingProvider.startRequest(underlyingRequest)
            {
            res, data, err in
            DispatchQueue.main.async
                {
                self.responseReceived(
                    underlyingResponse: res,
                    body: data,
                    error: err,
                    completionHandler: completionHandler)
                }
            }
        self.networking = networking
        }

    func cancelUnderlyingOperation()
        {
        networking?.cancel()
        }

    func repeated() -> RequestDelegate
        {
        NetworkRequestDelegate(resource: resource, requestBuilder: requestBuilder)
        }

    // MARK: Progress

    func computeProgress() -> Double
        {
        if let networking = networking
            { progressComputation.update(from: networking.transferMetrics) }
        return progressComputation.fractionDone
        }

    var progressReportingInterval: TimeInterval
        { config.progressReportingInterval }

    // MARK: Response handling

    // Entry point for response handling. Triggered by RequestNetworking completion callback.
    private func responseReceived(
            underlyingResponse: HTTPURLResponse?,
            body: Data?,
            error: Error?,
            completionHandler: RequestCompletionHandler)
        {
        DispatchQueue.mainThreadPrecondition()

        SiestaLog.log(.network, ["Response: ", underlyingResponse?.statusCode ?? error, "←", requestDescription])
        SiestaLog.log(.networkDetails, ["Raw response headers:", underlyingResponse?.allHeaderFields])
        SiestaLog.log(.networkDetails, ["Raw response body:", body?.count ?? 0, "bytes"])

        let responseInfo = interpretResponse(underlyingResponse, body, error)

        if completionHandler.willIgnore(responseInfo)
            { return }

        progressComputation.complete()

        transformResponse(responseInfo, then: completionHandler.broadcastResponse)
        }

    private func isError(httpStatusCode: Int?) -> Bool
        {
        guard let httpStatusCode = httpStatusCode else
            { return false }
        return httpStatusCode >= 400
        }

    private func interpretResponse(
            _ underlyingResponse: HTTPURLResponse?,
            _ body: Data?,
            _ error: Error?)
        -> ResponseInfo
        {
        if isError(httpStatusCode: underlyingResponse?.statusCode) || error != nil
            {
            return ResponseInfo(
                response: .failure(RequestError(response: underlyingResponse, content: body, cause: error)))
            }
        else if underlyingResponse?.statusCode == 304
            {
            if let entity = resource.latestData
                {
                return ResponseInfo(response: .success(entity), isNew: false)
                }
            else
                {
                return ResponseInfo(
                    response: .failure(RequestError(
                        userMessage: NSLocalizedString("No data available", comment: "userMessage"),
                        cause: RequestError.Cause.NoLocalDataFor304())))
                }
            }
        else
            {
            return ResponseInfo(response: .success(Entity<Any>(response: underlyingResponse, content: body ?? Data())))
            }
        }

    private func transformResponse(
            _ rawInfo: ResponseInfo,
            then afterTransformation: @escaping (ResponseInfo) -> Void)
        {
        let processor = config.pipeline.makeProcessor(rawInfo.response, resource: resource)

        let processingQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated)
        processingQueue.async
            {
            var processedInfo: ResponseInfo
            if rawInfo.isNew
                {
                processedInfo = processor()
                processedInfo.isNew = true
                processedInfo.configurationSource = .init(method: self.method, resource: self.resource)
                }
            else
                { processedInfo = rawInfo }  // result from a 304 is already transformed, cached, etc.

            DispatchQueue.main.async
                { afterTransformation(processedInfo) }
            }
        }
    }
