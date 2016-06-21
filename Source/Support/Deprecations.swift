//
//  Deprecations.swift
//  Siesta
//
//  Created by Paul on 2015/12/12.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//


import Foundation

// MARK: - Deprecated in beta 7

extension Resource
    {
    @available(*, deprecated=0.99, message="This property is going away from the public API. If you have a need for it, please file a Github issue describing your use case.")
    public var config: Configuration
        { return generalConfig }
    }

extension Configuration
    {
    @available(*, deprecated=0.99, message="Use .pipeline[…] with the appropriate stage, usually .parsing or .model.", renamed="pipeline[.parsing]")
    public var responseTransformers: TransformerSequence
        {
        get { return TransformerSequence(stage: pipeline[.parsing]) }
        set { pipeline[.parsing] = newValue.stage }
        }

    @available(*, deprecated=0.99, message="Use .pipeline[…].cache with the appropriate stage, usually .parsing or .cleanup.", renamed="pipeline[.parsing].cache")
    public var persistentCache: EntityCache?
        {
        get { return pipeline[.cleanup].cache }
        set { pipeline[.cleanup].cache = newValue }
        }
    }

@available(*, deprecated=0.99, message="Use Pipeline instead")
public struct TransformerSequence
    {
    private var stage: PipelineStage

    private init(stage: PipelineStage)
        { self.stage = stage }

    public mutating func clear()
        {
        stage.removeTransformers()
        stage.cache = nil
        }

    public mutating func add(
            transformer: ResponseTransformer,
            contentTypes: [String])
        {
        stage.add(transformer, contentTypes: contentTypes)
        }

    public mutating func add(transformer: ResponseTransformer)
        {
        stage.add(transformer)
        }
    }
