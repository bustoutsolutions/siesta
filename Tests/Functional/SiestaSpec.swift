//
//  SiestaSpec.swift
//  Siesta
//
//  Created by Paul on 2015/7/29.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Quick
@testable import Siesta

private var currentLogMessages: [String] = []
private var currentTestFailed: Bool = false

class SiestaSpec: QuickSpec
    {
    override func spec()
        {
        beforeSuite
            {
            Siesta.LogCategory.enabled = LogCategory.all
            Siesta.logger = { currentLogMessages.append($1) }
            }

        beforeEach
            {
            currentTestFailed = false
            currentLogMessages.removeAll(keepingCapacity: true)
            }

        afterEach
            {
            (exampleMetadata: Quick.ExampleMetadata) in

            resultsAggregator.recordResult(self, example: exampleMetadata.example, passed: !currentTestFailed)

            if currentTestFailed
                {
                print("Log output for spec:")
                print("────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────")
                for message in currentLogMessages
                    { print(message) }
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("")
                }
            }

        afterSuite
            {
            resultsAggregator.flush()
            }
        }

    override func recordFailure(withDescription description: String, inFile filePath: String, atLine lineNumber: UInt, expected: Bool)
        {
        currentTestFailed = true
        super.recordFailure(withDescription: description, inFile: filePath, atLine: lineNumber, expected: expected)
        }
    }


private let resultsAggregator = ResultsAggregator()

private class ResultsAggregator
    {
    private var results: Result = Result(name: "Root")
    private var resultsDirty = false

    func flush()
        {
        if !resultsDirty
            { return }

        let json = ["results": results.toJson["children"]!]
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
        if !((try? jsonData.write(to: URL(fileURLWithPath: "/tmp/siesta-spec-results.json"), options: [.atomic])) != nil)
            { print("unable to write spec results json") }

        resultsDirty = false
        }

    func recordResult(_ spec: QuickSpec, example: Example, passed: Bool)
        {
        recordResult(
            [specDescription(spec)] + example.name.components(separatedBy: ", "),
            subtree: results,
            callsite: example.callsite,
            passed: passed)
        resultsDirty = true
        }

    private func recordResult(_ path: [String], subtree: Result, callsite: Quick.Callsite, passed: Bool)
        {
        if let pathComponent = path.first
            {
            recordResult(
                Array(path[1 ..< path.count]),
                subtree: subtree.child(pathComponent),
                callsite: callsite,
                passed: passed)
            }
        else
            {
            subtree.callsite = callsite
            subtree.passed = passed
            }
        }

    private func specDescription(_ spec: QuickSpec) -> String
        {
        return type(of: spec).description()
            .replacing(regex: "^[A-Za-z]+Tests\\.", with: "")
            .replacing(regex: "\\.Type$",           with: "")
        }
    }

private class Result
    {
    let name: String
    var callsite: Quick.Callsite?
    var passed: Bool?
    var children: [Result] = []

    init(name: String)
        { self.name = name }

    func child(_ named: String) -> Result
        {
        for child in children
            where child.name == named
                { return child }
        let newChild = Result(name: named)
        children.append(newChild)
        return newChild
        }

    var toJson: [String:Any]
        {
        var json: [String:Any] = ["name": name]
        if let callsite = callsite
            {
            json["file"] = callsite.file
            json["line"] = callsite.line
            }
        if let passed = passed
            { json["passed"] = passed }
        if !children.isEmpty
            { json["children"] = children.map { $0.toJson } }
        return json
        }
    }
