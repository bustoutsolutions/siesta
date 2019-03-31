//
//  FileCache.swift
//  Siesta
//
//  Created by Paul on 2017/11/22.
//  Copyright © 2017 Bust Out Solutions. All rights reserved.
//

#if !COCOAPODS
    import Siesta
#endif
import CommonCrypto

private typealias File = URL

private let fileCacheFormatVersion: [UInt8] = [0]

private let decoder = PropertyListDecoder()
private let encoder: PropertyListEncoder =
    {
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    return encoder
    }()

public struct FileCache<ContentType>: EntityCache, CustomStringConvertible
    where ContentType: Codable
    {
    private let isolationStrategy: DataIsolationStrategy
    private let cacheDir: File

    public let description: String

    public init(poolName: String = "Default", dataIsolation isolationStrategy: DataIsolationStrategy) throws
        {
        let cacheDir = try FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "")  // no bundle → directly inside cache dir
            .appendingPathComponent("Siesta")
            .appendingPathComponent(poolName)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        self.init(inDirectory: cacheDir, dataIsolation: isolationStrategy, cacheName: "poolName: " + poolName)
        }

    public init(
            inDirectory cacheDir: URL,
            dataIsolation isolationStrategy: DataIsolationStrategy,
            cacheName: String? = nil)
        {
        self.cacheDir = cacheDir
        self.isolationStrategy = isolationStrategy
        self.description = "\(type(of: self))(\(cacheName ?? cacheDir.path))"
        }

    // MARK: - Keys and filenames

    public func key(for resource: Resource) -> Key?
        { return Key(resource: resource, isolationStrategy: isolationStrategy) }

    public struct Key: CustomStringConvertible
        {
        fileprivate var hash: String
        private var url: URL

        fileprivate init(resource: Resource, isolationStrategy: DataIsolationStrategy)
            {
            url = resource.url
            hash = isolationStrategy.keyData(for: url)
                .sha256
                .urlSafeBase64EncodedString
            }

        public var description: String
            { return "FileCache.Key(\(url))" }
        }

    private func file(for key: Key) -> File
        { return cacheDir.appendingPathComponent(key.hash + ".cache") }

    // MARK: - Reading and writing

    public func readEntity(forKey key: Key) throws -> Entity<ContentType>?
        {
        do  {
            return try
                decoder.decode(
                    Entity<ContentType>.self,
                    from: Data(contentsOf: file(for: key)))
                .entity
            }
        catch CocoaError.fileReadNoSuchFile
            { }  // a cache miss is just fine; don't log it
        return nil
        }

    public func writeEntity(_ entity: Entity<ContentType>, forKey key: Key) throws
        {
        try encoder.encode(entity)
            .write(to: file(for: key), options: [.atomic, .completeFileProtection])
        }

    public func removeEntity(forKey key: Key) throws
        {
        try FileManager.default.removeItem(at: file(for: key))
        }
    }

extension FileCache
    {
    public struct DataIsolationStrategy
        {
        private let keyPrefix: Data

        private init(keyIsolator: Data)
            {
            keyPrefix =
                fileCacheFormatVersion         // prevents us from parsing old cache entries using some new future format
                                               // TODO: include pipeline stage name here
                 + "\(ContentType.self)".utf8  // prevent data collision when caching at multiple pipeline stages
                 + [0]                         // null-terminate ContentType to prevent bleed into username
                 + keyIsolator                 // prevents one user from seeing another’s cached requests
                 + [0]                         // separator for URL
            }

        fileprivate func keyData(for url: URL) -> Data
            {
            return Data(keyPrefix + url.absoluteString.utf8)
            }

        public static var sharedByAllUsers: DataIsolationStrategy
            { return DataIsolationStrategy(keyIsolator: Data()) }

        public static func perUser<T>(identifiedBy partitionID: T) throws -> DataIsolationStrategy
            where T: Codable
            {
            return DataIsolationStrategy(
                keyIsolator: try encoder.encode([partitionID]))
            }
        }
    }

// MARK: - Encryption helpers

extension Data
    {
    fileprivate var sha256: Data
        {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = withUnsafeBytes
            { CC_SHA256($0.baseAddress, CC_LONG(count), &hash) }
        return Data(hash)
        }

    fileprivate var shortenWithSHA256: Data
        {
        return count > 32 ? sha256 : self
        }

    fileprivate var urlSafeBase64EncodedString: String
        {
        return base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        }
    }
