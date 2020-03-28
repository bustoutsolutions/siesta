//
//  PipelineSpec.swift
//  Siesta
//
//  Created by Paul on 2016/6/4.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta

import Foundation
import Quick
import Nimble

class PipelineSpec: ResourceSpecBase
    {
    override func resourceSpec(_ service: @escaping () -> Service, _ resource: @escaping () -> Resource)
        {
        beforeEach
            {
            configureStageNameAppenders(in: service())
            }

        describe("stage order")
            {
            it("determines transformer order")
                {
                stubAndAwaitRequest(for: resource())
                expect(resource().text) == "decparmodcle"
                }

            it("can reorder transformers already added")
                {
                service().configure
                    { $0.pipeline.order = [.rawData, .parsing, .cleanup, .model, .decoding] }
                stubAndAwaitRequest(for: resource())
                expect(resource().text) == "parclemoddec"
                }

            it("will skip unlisted stages")
                {
                service().configure
                    { $0.pipeline.order = [.parsing, .decoding] }
                stubAndAwaitRequest(for: resource())
                expect(resource().text) == "pardec"
                }

            it("supports custom keys")
                {
                service().configure
                    {
                    $0.pipeline.order.insert(.funk, at: 3)
                    $0.pipeline.order.insert(.silence, at: 1)
                    $0.pipeline[.funk].add(stringAppendingTransformer("♫"))
                    }
                stubAndAwaitRequest(for: resource())
                expect(resource().text) == "decpar♫modcle"
                }
            }

        describe("individual stage")
            {
            it("runs transformers in the order added")
                {
                service().configure
                    {
                    for solfegg in ["do", "re", "mi"]
                        { $0.pipeline[.decoding].add(stringAppendingTransformer(solfegg)) }
                    }
                stubAndAwaitRequest(for: resource())
                expect(resource().text) == "decdoremiparmodcle"
                }

            it("can clear and replace transformers")
                {
                service().configure
                    {
                    $0.pipeline[.model].removeTransformers()
                    $0.pipeline[.model].add(stringAppendingTransformer("ti"))
                    }
                stubAndAwaitRequest(for: resource())
                expect(resource().text) == "decparticle"
                }
            }

        it("can clear previously configured transformers")
            {
            service().configure
                { $0.pipeline.clear() }
            stubAndAwaitRequest(for: resource())
            expect(resource().latestData?.content is NSData) == true
            }
        }
    }


private func stringAppendingTransformer(_ word: String) -> ResponseContentTransformer<Any,String>
    {
    return ResponseContentTransformer
        {
        let stringContent = $0.text
        guard !stringContent.contains("error on \(word)") else
            { return nil }
        return stringContent + word
        }
    }

func configureStageNameAppenders(in service: Service)
    {
    service.configure
        {
        $0.pipeline.clear()
        for stage in [.decoding, .parsing, .model, .cleanup] as [PipelineStageKey]
            {
            $0.pipeline[stage].add(
                stringAppendingTransformer(String(stage.description.prefix(3))))
            }
        }
    }

extension PipelineStageKey
    {
    fileprivate static let
        funk    = PipelineStageKey(description: "funk"),
        silence = PipelineStageKey(description: "silence")
    }
