//
//  StandardTransformers.swift
//  Siesta
//
//  Created by Paul on 2017/8/4.
//  Copyright © 2017 Bust Out Solutions. All rights reserved.
//

/**
  A preconfigured combination of a transformer, content type, and pipeline stage.
  Use this to individually opt in to Siesta’s built-in response transformers.

  - SeeAlso: `Service.init(...)`’s `standardTransformers:` parameter
*/
public struct StandardTransformer
    {
    // Hello, reader of source code! Do you find yourself wanting these properties to be public, so that you can create
    // your own standard transformer + content type + pipeline stage groupings for easy reuse? I am hesitant to expose
    // all of this as public API, but if you have a problem it would solve, please open a GitHub issue and talk me
    // through your use case. –PPC

    internal let name: String
    internal let transformer: ResponseTransformer
    internal let contentTypes: [String]
    internal let stage: PipelineStageKey
    }

extension StandardTransformer
    {
    /**
      Uses Foundation’s `JSONSerialization` to transform responses
      - with content type of `*​/json` or `*​/​*+json`
      - to a dictionary or array
      - at the parsing stage.

      Disable this if you want to use a different parser, such as Swift 4’s `JSONDecoder`:

          let service = Service(
            baseURL: "https://example.com",
            standardTransformers: [.image, .text])  // no .json

          let jsonDecoder = JSONDecoder()
          service.configureTransformer("/foo") {
            try jsonDecoder.decode(Foo.self, from: $0.content)
          }

      - SeeAlso: `JSONResponseTransformer(_:)` to configure a JSON parser with different options, at a different stage,
          or for different content types.
    */
    public static let json =
        StandardTransformer(
            name: "JSON", transformer: JSONResponseTransformer(), contentTypes: ["*/json", "*/*+json"], stage: .parsing)

    /**
      Parses responses with content type `text/​*` as a Swift `String`.

      - SeeAlso: `TextResponseTransformer(_:)` to configure a text parser with different options, at a different stage,
          or for different content types.
    */
    public static let text =
        StandardTransformer(
            name: "text", transformer: TextResponseTransformer(), contentTypes: ["text/*"], stage: .parsing)

    /**
      Parses responses with content type `image/​*` as a UIKit / AppKit image.

      - SeeAlso: `ImageResponseTransformer(_:)` to configure an image parser with different options, at a different
          stage, or for different content types.
    */
    public static let image =
        StandardTransformer(
            name: "image", transformer: ImageResponseTransformer(), contentTypes: ["image/*"], stage: .parsing)
    }

extension Pipeline
    {
    /**
      Adds one of Siesta’s standard tranformers to a pipeline. Useful if you omitted one of the standard transformers
      in `Service.init(...)`, but still want to configure it for certain resources.
    */
    public mutating func add(_ transformer: StandardTransformer)
        {
        self[transformer.stage].add(transformer.transformer, contentTypes: transformer.contentTypes)
        }
    }
