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
        add(
            method,
            resource,
            returning: HTTPResponse(status: status))
        }

    static func add(
            _ method: RequestMethod,
            _ resource: @escaping () -> Resource,
            returning response: NetworkStubResponse)
        {
        add(
            matching: RequestPattern(
                method: method.rawValue.uppercased(),
                url: resource().url.absoluteString),
            returning: response)
        }

    static func add(
            matching matcher: RequestPattern,
            returning stubResponse: NetworkStubResponse)
        {
        add(RequestStub(
            matcher: matcher,
            response: stubResponse))
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

            let body = extractBody(from: request)

            let stubs = Self.stubs
            guard let stub = stubs.first(where: { $0.matcher.matches(request, withBody: body) }) else
                {
                fatalError(
                    """
                    Unstubbed network request:
                        \(request.httpMethod ?? "<nil method>") \(request.url?.absoluteString ?? "<nil URL>")
                        headers: \(request.allHTTPHeaderFields ?? [:])
                        body: \(body?.description ?? "nil")

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

    private static func extractBody(from request: URLRequest) -> Data?
        {
        if let data = request.httpBody
            { return data }
        if let stream = request.httpBodyStream
            {
            // adapted from https://forums.swift.org/t/pitch-make-inputstream-and-outputstream-methods-safe-and-swifty/23726
            var buffer = [UInt8](repeating: 0, count: 65536)

            stream.open()
            defer { stream.close() }

            let bytesRead = stream.read(&buffer, maxLength: buffer.count)
            if bytesRead < 0
                { fatalError("Unable to ready HTTP body stream: \(stream.streamError?.localizedDescription ?? "unknown error")") }
            return Data(buffer.prefix(bytesRead))
            }
        return nil
        }

    override func startLoading()
        {
        let stub = URLProtocol.property(forKey: stubPropertyKey, in: request) as! RequestStub
        stub.delayLatch.await()

        Thread.sleep(forTimeInterval: 1.0 / pow(.random(in: 1...1000), 2))

        stub.response.send(to: self.client!, for: self, url: request.url!)
        }

    override func stopLoading()
        { }
    }

protocol HTTPBodyConvertible
    {
    var httpData: Data { get }
    }

extension Data: HTTPBodyConvertible
    {
    var httpData: Data
        { self }
    }

extension String: HTTPBodyConvertible
    {
    var httpData: Data
        { data(using: .utf8)! }
    }

struct RequestPattern
    {
    var method: String
    var url: String
    var headers = [String:String]()
    var body: HTTPBodyConvertible?


    func matches(_ request: URLRequest, withBody requestBody: Data?) -> Bool
        {
        return request.httpMethod == method
            && request.url?.absoluteString == url
            && headers.allSatisfy
                {
                key, value in
                request.allHTTPHeaderFields?[key] == value
                }
            && body?.httpData == requestBody
        }
    }

protocol NetworkStubResponse
    {
    func send(to client: URLProtocolClient, for sender: URLProtocol, url: URL)
    }

struct ErrorResponse: NetworkStubResponse
    {
    var error: Error

    func send(to client: URLProtocolClient, for sender: URLProtocol, url: URL)
        {
        client.urlProtocol(sender, didFailWithError: error)
        }
    }

struct HTTPResponse: NetworkStubResponse
    {
    var status = 200
    var headers = [String:String]()
    var body: HTTPBodyConvertible?

    func send(to client: URLProtocolClient, for sender: URLProtocol, url: URL)
        {
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "1.1",
            headerFields: headers)!

        client.urlProtocol(sender, didReceive: response, cacheStoragePolicy: .notAllowed)

        if let bodyData = body?.httpData
            { client.urlProtocol(sender, didLoad: bodyData) }

        client.urlProtocolDidFinishLoading(sender) // TODO: Should error do this as well?
        }
    }

class RequestStub
    {
    var matcher: RequestPattern
    var response: NetworkStubResponse

    init(matcher: RequestPattern, response: NetworkStubResponse)
        {
        self.matcher = matcher
        self.response = response
        }

    let delayLatch = Latch(name: "delayed request")

    var description: String
        { "\(matcher) → \(response)" }
    }

@discardableResult
func stubRequest(_ resource: () -> Resource, _ method: String) -> LSStubRequestDSL
    {
    let stub = RequestStub(
        matcher: RequestPattern(method: method, url: resource().url.absoluteString),
        response: HTTPResponse(status: 200))
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
            { stub.matcher.headers[key] = value }
        return self
        }

    func withBody(_ data: HTTPBodyConvertible) -> Self
        {
        stub.matcher.body = data
        return self
        }

    func andReturn(_ status: Int) -> LSStubResponseDSL
        {
        var response = stub.response as! HTTPResponse
        response.status = status
        stub.response = response
        return LSStubResponseDSL(stub: stub)
        }

    func andFailWithError(_ error: Error)
        {
        stub.response = ErrorResponse(error: error)
        }
    }

class LSStubResponseDSL
    {
    var stub: RequestStub

    init(stub: RequestStub)
        { self.stub = stub }

    func withHeader(_ key: String, _ value: String?) -> Self
        {
        var response = stub.response as! HTTPResponse
        response.headers[key] = value
        stub.response = response
        return self
        }

    func withBody(_ data: HTTPBodyConvertible?) -> Self
        {
        var response = stub.response as! HTTPResponse
        response.body = data
        stub.response = response
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
