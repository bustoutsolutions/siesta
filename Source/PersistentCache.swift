//
//  PersistentCache.swift
//  Siesta
//
//  Created by Paul on 2015/8/24.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

public protocol EntityCache
    {
    func readEntity(forUrl url: NSURL) -> Entity?
    func writeEntity(entity: Entity, forUrl: NSURL)
    }



public protocol EntityEncoder
    {
    func encodeEntity(entity: Entity) -> NSData?
    func decodeEntity(data: NSData) -> Entity?
    }

public struct JSONEntityEncoder: EntityEncoder
    {
    public init() { }
    
    public func encodeEntity(entity: Entity) -> NSData?
        {
        guard NSJSONSerialization.isValidJSONObject(entity.content) else
            { return nil }
        
        let json = NSMutableDictionary()
        json["content"]   = entity.content
        json["headers"]   = entity.headers
        json["charset"]   = entity.charset
        json["timestamp"] = entity.timestamp
        
        do  { return try NSJSONSerialization.dataWithJSONObject(json, options: []) }
        catch { return nil }
        }
    
    public func decodeEntity(data: NSData) -> Entity?
        {
        let decoded: AnyObject
        do { decoded = try NSJSONSerialization.JSONObjectWithData(data, options: []) }
        catch { return nil }
        
        guard let json = decoded as? NSDictionary,
                  content   = json["content"],
                  headers   = json["headers"] as? [String:String],
                  timestamp = json["timestamp"] as? NSTimeInterval
        else { return nil}
        
        let charset = json["charset"] as? String  // can be nil
        
        return Entity(content: content, charset: charset, headers: headers, timestamp: timestamp)
        }
    }
