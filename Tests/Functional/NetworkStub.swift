//
//  NetworkStub.swift
//  Siesta
//
//  Created by Paul on 2020/3/22.
//  Copyright © 2020 Bust Out Solutions. All rights reserved.
//

import Foundation
import Siesta

private let stubPropertyKey = "\(NetworkStub.self).stub"

private let lock = NSObject()
func synchronized<T>(_ action: () -> T) -> T
    {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    return action()
    }

final class NetworkStub: URLProtocol
    {
    private static var stubs = [RequestStub]()
    private static var requestInitialization = Latch(name: "initialization of requests")

    static var defaultConfiguration: URLSessionConfiguration
        { wrap(URLSessionConfiguration.ephemeral) }

    static func wrap(_ configuration: URLSessionConfiguration) -> URLSessionConfiguration
        {
        configuration.protocolClasses = [NetworkStub.self]
        return configuration
        }

    static func add(
            _ method: RequestMethod,
            _ resource: @escaping () -> Resource,
            status: Int = 200)
        {
        add(RequestStub(
            method: method.rawValue.uppercased(),
            url: resource().url.absoluteString,
            status: status))
        }

    static func add(_ stub: RequestStub)
        {
        synchronized
            { stubs.insert(stub, at: 0) }
        }

    static func clearAll()
        {
        Self.requestInitialization.await
            { stubs = [] }
        }

    override class func canInit(with request: URLRequest) -> Bool
        {
        Self.requestInitialization.increment()
        return true
        }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest
        {
        synchronized
            {
            defer
                { Self.requestInitialization.decrement() }

            let stubs = Self.stubs
            guard let stub = stubs.first(where: { $0.matches(request) }) else
                {
                fatalError(
                    """
                    Unstubbed network request:
                        \(request.httpMethod ?? "<nil method>") \(request.url?.absoluteString ?? "<nil URL>")
                        headers: \(request.allHTTPHeaderFields ?? [:])
                        body: \(request.httpBody?.description ?? "nil")

                    Available stubs:
                        \(stubs.map { $0.description }.joined(separator: "\n    "))

                    Halting tests
                    """)
                }

            let mutableRequest = request as! NSMutableURLRequest
            URLProtocol.setProperty(stub, forKey: stubPropertyKey, in: mutableRequest)
            return mutableRequest as URLRequest
            }
        }

    override func startLoading()
        {
        let stub = URLProtocol.property(forKey: stubPropertyKey, in: request) as! RequestStub
        stub.delayLatch.await()

        let client = self.client!

        if let error = stub.responseError
            {
            client.urlProtocol(self, didFailWithError: error)
            return
            }
        else
            {
            Thread.sleep(forTimeInterval: 1.0 / pow(.random(in: 1...1000), 2))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: stub.responseCode,
                httpVersion: "1.1",
                headerFields: stub.responseHeaders)!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = stub.responseBody
                { client.urlProtocol(self, didLoad: data) }
            }

        client.urlProtocolDidFinishLoading(self)
        }

    override func stopLoading()
        { }
    }

class RequestStub
    {
    var method: String
    var url: String

    init(method: String, url: String, status: Int = 200)
        {
        self.method = method
        self.url = url
        self.responseCode = status
        }

    var requestHeaders = [String:String]()
    var requestBody: Data?

    var responseError: Error?
    var responseCode: Int
    var responseHeaders = [String:String]()
    var responseBody: Data?

    let delayLatch = Latch(name: "delayed request")

    func matches(_ request: URLRequest) -> Bool
        {
        return request.httpMethod == method
            && request.url?.absoluteString == url
            && requestHeaders.allSatisfy
                {
                key, value in
                request.allHTTPHeaderFields?[key] == value
                }
        }

    var description: String
        { "\(method) \(url) requestHeaders=\(requestHeaders) body=\(requestBody?.description ?? "<any>")" }
    }

@discardableResult
func stubRequest(_ resource: () -> Resource, _ method: String) -> LSStubRequestDSL
    {
    let stub = RequestStub(method: method, url: resource().url.absoluteString)
    NetworkStub.add(stub)
    return LSStubRequestDSL(stub: stub)
    }

class LSStubRequestDSL
    {
    var stub: RequestStub

    init(stub: RequestStub)
        { self.stub = stub }

    func withHeader(_ key: String, _ value: String?) -> Self
        {
        synchronized
            { stub.requestHeaders[key] = value }
        return self
        }

    func withBody(_ string: String) -> Self
        { withBody(string.data(using: .utf8)!) }

    func withBody(_ data: Data) -> Self
        {
        stub.requestBody = data
        return self
        }

    func andReturn(_ statusCode: Int) -> LSStubResponseDSL
        {
        stub.responseCode = statusCode
        return LSStubResponseDSL(stub: stub)
        }

    func andFailWithError(_ error: Error)
        {
        stub.responseError = error
        }
    }

class LSStubResponseDSL
    {
    var stub: RequestStub

    init(stub: RequestStub)
        { self.stub = stub }

    func withHeader(_ key: String, _ value: String?) -> Self
        {
        stub.responseHeaders[key] = value
        return self
        }

    func withBody(_ string: String?) -> Self
        { withBody(string?.data(using: .utf8)!) }

    func withBody(_ data: Data?) -> Self
        {
        stub.responseBody = data
        return self
        }

    func delay() -> Self
        {
        stub.delayLatch.increment()
        return self
        }

    func go() -> Self
        {
        stub.delayLatch.decrement()
        return self
        }
    }

struct LSNocilla
    {
    static func sharedInstance() -> Self
        { LSNocilla() }

    func clearStubs()
        { NetworkStub.clearAll() }
    }

struct Latch
    {
    private var lock = NSConditionLock(condition: 0)

    let name: String

    init(name: String)
        { self.name = name }

    func increment()
        { add(1) }

    func decrement()
        { add(-1) }

    private func add(_ delta: Int)
        {
        lock.lock()
        lock.unlock(withCondition: lock.condition + delta)
        }

    func await(target: Int = 0, whileLocked action: () -> Void = {})
        {
        guard lock.lock(whenCondition: target, before: Date(timeIntervalSinceNow: 1)) else
            { fatalError("timed out waiting for \(name)") }
        action()
        lock.unlock()
        }
    }
