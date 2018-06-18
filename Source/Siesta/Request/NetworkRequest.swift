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
    internal var config: Configuration
        { return resource.configuration(for: underlyingRequest) }
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
        return NetworkRequestDelegate(resource: resource, requestBuilder: requestBuilder)
        }

    // MARK: Progress

    func computeProgress() -> Double
        {
        if let networking = networking
            { progressComputation.update(from: networking.transferMetrics) }
        return progressComputation.fractionDone
        }

    var progressReportingInterval: TimeInterval
        { return config.progressReportingInterval }

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

        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async
            {
            let processedInfo =
                rawInfo.isNew
                    ? ResponseInfo(response: processor(), isNew: true)
                    : rawInfo

            DispatchQueue.main.async
                { afterTransformation(processedInfo) }
            }
        }
    }
