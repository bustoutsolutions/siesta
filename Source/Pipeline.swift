//
//  Pipeline.swift
//  Siesta
//
//  Created by Paul on 2016/6/3.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

public final class PipelineStageKey: _OpenEnum, CustomStringConvertible
    {
    public let description: String

    public init(description: String)
        { self.description = description }
    }

public extension PipelineStageKey
    {
    public static let
        rawData = PipelineStageKey(description: "rawData"),
        decoding = PipelineStageKey(description: "decoding"),
        parsing = PipelineStageKey(description: "parsing"),
        model = PipelineStageKey(description: "model"),
        cleanup = PipelineStageKey(description: "cleanup")
    }

public struct Pipeline
    {
    private var stages: [PipelineStageKey:PipelineStage] = [:]

    private var stagesInOrder: [PipelineStage]
        { return order.flatMap { stages[$0] } }

    public var order: [PipelineStageKey] = [.rawData, .decoding, .parsing, .model, .cleanup]
        {
        willSet
            {
            precondition(
                newValue.count == Set(newValue).count,
                "Pipeline.order contains duplicates: \(newValue)")

            let nonEmptyStages = stages
                .filter { _, stage in !stage.isEmpty }
                .map { key, _ in key }
            let missingStages = Set(nonEmptyStages).subtract(newValue)
            if !missingStages.isEmpty
                { debugLog(.ResponseProcessing, ["WARNING: Stages", missingStages, "configured but not present in custom pipeline order, will be ignored:", newValue]) }
            }
        }

    public subscript(key: PipelineStageKey) -> PipelineStage
        {
        get { return stages[key] ?? PipelineStage() }
        set { stages[key] = newValue }
        }

    var containsCaches: Bool
        { return stages.any { $1.cache != nil } }

    public mutating func removeAllTransformers()
        {
        for key in stages.keys
            { stages[key]?.removeTransformers() }
        }

    public mutating func removeAllCaches()
        {
        for key in stages.keys
            { stages[key]?.cache = nil }
        }

    public mutating func clear()
        {
        removeAllTransformers()
        removeAllCaches()
        }

    func process(response: Response) -> Response
        { return process(response, usingStages: stagesInOrder) }

    private func process<Stages: CollectionType where Stages.Generator.Element == PipelineStage>(
            response: Response,
            usingStages stages: Stages)
        -> Response
        {
        return stages.reduce(response)
            { resp, stage in stage.process(resp) }
        }

    func readFromCache(key key: String, onHit: (Entity) -> ())
        {
        guard containsCaches else
            { return }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0))
            {
            guard let entity = self.cachedEntity(forKey: key) else
                { return }

            dispatch_async(dispatch_get_main_queue())
                { onHit(entity) }
            }
        }

    private func cachedEntity(forKey key: String) -> Entity?
        {
        let stagesInOrder = self.stagesInOrder
        for (index, stage) in stagesInOrder.enumerate().reverse()
            {
            if let result = stage.cache?.readEntity(forKey: key)
                {
                debugLog(.Cache, ["Cache hit at", stage, "stage for", self, "in", stage.cache])

                let processed = process(
                    .Success(result),
                    usingStages: stagesInOrder.suffixFrom(index + 1))

                switch(processed)
                    {
                    case .Failure:
                        debugLog(.Cache, ["Error processing cached entity; will ignore cached value. Error:", processed])

                    case .Success(let entity):
                        return entity
                    }
                }
            }
        return nil
        }
    }

public struct PipelineStage
    {
    public var cache: EntityCache?

    private var transformers: [ResponseTransformer] = []

    public mutating func add(transformer: ResponseTransformer)
        { transformers.append(transformer) }

    public mutating func add(
            transformer: ResponseTransformer,
            contentTypes: [String])
        {
        add(ContentTypeMatchTransformer(
            transformer, contentTypes: contentTypes))
        }

    public mutating func removeTransformers()
        { transformers.removeAll() }

    private var isEmpty: Bool
        { return cache == nil && transformers.isEmpty }

    func process(response: Response) -> Response
        {
        return transformers.reduce(response)
            { $1.process($0) }
        }
    }
