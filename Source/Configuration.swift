//
//  Configuration.swift
//  Siesta
//
//  Created by Paul on 2015/8/8.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

/**
  Options which control the behavior of a `Resource`.
  
  - SeeAlso: `Service.configureResources(...)`
*/
public struct Configuration
    {
    /**
      Time before valid data is considered stale by `loadIfNeeded()`.
      
      Defaults from `Service.defaultExpirationTime`, which defaults to 30 seconds.
    */
    public var expirationTime: NSTimeInterval = 30
    
    /**
      Time `loadIfNeeded()` will wait before allowing a retry after a failed request.
    
      Defaults from `Service.defaultRetryTime`, which defaults to 1 second.
    */
    public var retryTime: NSTimeInterval = 1
    
    /**
      A sequence of parsers to be applied to responses.
      
      You can add custom parsing using:
      
          responseTransformers.add(MyCustomTransformer())
          responseTransformers.add(MyCustomTransformer(), contentTypes: ["foo/bar"])
      
      By default, the transformer sequence includes JSON and plain text parsing. You can
      remove this default behavior by clearing the sequence:
      
          responseTransformers.clear()
    */
    public var responseTransformers: TransformerSequence = TransformerSequence()
    
    /**
      Default request headers.
    */
    public var headers: [String:String] = [:]
    
    /**
      Holds a mutable configuration while closures passed to `Service.configureResources(...)` modify it.
    
      The reason that method doesn’t just accept a closure with an `inout` param is that doing so requires a messy
      flavor of closure declaration that makes the API much harder to use:
      
          configureResources("/things/​*") { (inout config: Configuration) in config.retryTime = 1 }
    
      This wrapper class allows usage to instead look like:
    
          configureResources("/things/​*") { $0.config.retryTime = 1 }
    */
    public class Builder
        {
        /// Mutable for modification while building a resource’s config.
        public var config: Configuration = Configuration()
        }
    }
