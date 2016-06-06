//
//  PipelineSpec.swift
//  Siesta
//
//  Created by Paul on 2016/6/4.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta
import Quick
import Nimble
import Nocilla

class PipelineSpec: ResourceSpecBase
    {
    override func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        {
        func appender(word: String) -> ResponseContentTransformer<Any,String>
            {
            return ResponseContentTransformer(skipWhenEntityMatchesOutputType: false)
                {
                ($0.content as? String ?? "") + word
                }
            }

        func makeRequest()
            {
            stubRequest(resource, "GET").andReturn(200).withBody("ignored")
            awaitNewData(resource().load())
            }

        beforeEach
            {
            service().configure
                {
                $0.config.pipeline.clear()
                for stage in [.decoding, .parsing, .model, .cleanup] as [PipelineStageKey]
                    {
                    $0.config.pipeline[stage].add(
                        appender(stage.description.initialSubstring(3)))
                    }
                }
            }

        describe("stage order")
            {
            it("determines transformer order")
                {
                makeRequest()
                expect(resource().text) == "decparmodcle"
                }

            it("can reorder transformers already added")
                {
                service().configure
                    { $0.config.pipeline.order = [.rawData, .parsing, .cleanup, .model, .decoding] }
                makeRequest()
                expect(resource().text) == "parclemoddec"
                }

            it("will skip unlisted stages")
                {
                service().configure
                    { $0.config.pipeline.order = [.parsing, .decoding] }
                makeRequest()
                expect(resource().text) == "pardec"
                }

            it("supports custom keys")
                {
                service().configure
                    {
                    $0.config.pipeline.order.insert(.funk, atIndex: 3)
                    $0.config.pipeline.order.insert(.silence, atIndex: 1)
                    $0.config.pipeline[.funk].add(appender("♫"))
                    }
                makeRequest()
                expect(resource().text) == "decpar♫modcle"
                }
            }

        describe("stage")
            {
            it("runs transformers in the order added")
                {
                service().configure
                    {
                    for solfegg in ["do", "re", "mi"]
                        { $0.config.pipeline[.decoding].add(appender(solfegg)) }
                    }
                makeRequest()
                expect(resource().text) == "decdoremiparmodcle"
                }

            it("can clear and replace transformers")
                {
                service().configure
                    {
                    $0.config.pipeline[.model].removeTransformers()
                    $0.config.pipeline[.model].add(appender("ti"))
                    }
                makeRequest()
                expect(resource().text) == "decparticle"
                }
            }

        it("can clear previously configured transformers")
            {
            service().configure
                { $0.config.pipeline.clear() }
            makeRequest()
            expect(resource().latestData?.content is NSData) == true
            }
        }
    }


private extension PipelineStageKey
    {
    static let
        funk    = PipelineStageKey(description: "funk"),
        silence = PipelineStageKey(description: "silence")
    }


private extension String
    {
    func initialSubstring(n: Int) -> String
        {
        return self[startIndex ..< startIndex.advancedBy(n)]
        }
    }
