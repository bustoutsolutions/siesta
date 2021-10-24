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

public struct FileCache<ContentType>: EntityCache
    where ContentType: Codable
    {
    private let keyPrefix: Data
    private let cacheDir: File

    private let encoder = PropertyListEncoder()
    private let decoder = PropertyListDecoder()

    public init<T>(poolName: String = "Default", userIdentity: T?) throws
        where T: Encodable
        {
        encoder.outputFormat = .binary

        self.keyPrefix = try
            fileCacheFormatVersion           // prevents us from parsing old cache entries using some new future format
             + encoder.encode(userIdentity)  // prevents one user from seeing another’s cached requests
             + [0]                           // separator for URL

        cacheDir = try
            FileManager.default.url(
                for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "")
            .appendingPathComponent("Siesta")
            .appendingPathComponent(poolName)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }

    // MARK: - Keys and filenames

    public func key(for resource: Resource) -> Key?
        { Key(resource: resource, prefix: keyPrefix) }

    public struct Key: CustomStringConvertible
        {
        fileprivate var url, hash: String

        fileprivate init(resource: Resource, prefix: Data)
            {
            url = resource.url.absoluteString
            hash = Data(prefix + url.utf8)
                .sha256
                .urlSafeBase64EncodedString
            }

        public var description: String
            { "FileCache.Key(\(url))" }
        }

    private func file(for key: Key) -> File
        { cacheDir.appendingPathComponent(key.hash + ".plist") }

    // MARK: - Reading and writing

    public func readEntity(forKey key: Key) -> Entity<ContentType>?
        {
        do  {
            return try
                decoder.decode(EncodableEntity<ContentType>.self,
                    from: Data(contentsOf: file(for: key)))
                .entity
            }
        catch CocoaError.fileReadNoSuchFile
            { }  // a cache miss is just fine
        catch
            { SiestaLog.log(.cache, ["WARNING: FileCache unable to read cached entity for", key, ":", error]) }
        return nil
        }

    public func writeEntity(_ entity: Entity<ContentType>, forKey key: Key)
        {
        #if os(macOS)
            let options: Data.WritingOptions = [.atomic]
        #else
            let options: Data.WritingOptions = [.atomic, .completeFileProtection]
        #endif

        do  {
            try encoder.encode(EncodableEntity(entity))
                .write(to: file(for: key), options: options)
            }
        catch
            { SiestaLog.log(.cache, ["WARNING: FileCache unable to write entity for", key, ":", error]) }
        }

    public func removeEntity(forKey key: Key)
        {
        do  {
            try FileManager.default.removeItem(at: file(for: key))
            }
        catch
            { SiestaLog.log(.cache, ["WARNING: FileCache unable to clear cache entity for", key, ":", error]) }
        }
    }

/// Ideally, Entity itself would be codable when its ContentType is codable. To do this, Swift would need to:
///
///   1. allow conditional conformance, and
///   2. allow extensions to synthesize encode/decode.
///
/// This struct is a stopgap until the language can do all that.
///
private struct EncodableEntity<ContentType>: Codable
    where ContentType: Codable
    {
    var timestamp: TimeInterval
    var headers: [String:String]
    var charset: String?
    var content: ContentType

    init(_ entity: Entity<ContentType>)
        {
        timestamp = entity.timestamp
        headers = entity.headers
        charset = entity.charset
        content = entity.content
        }

    var entity: Entity<ContentType>
        { Entity(content: content, charset: charset, headers: headers, timestamp: timestamp) }
    }

extension Data
    {
    var sha256: Data
        {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = withUnsafeBytes
            { CC_SHA256($0.baseAddress, CC_LONG(count), &hash) }
        return Data(hash)
        }

    var urlSafeBase64EncodedString: String
        {
        base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        }
    }
