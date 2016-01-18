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

public class SiestaSpec: QuickSpec
    {
    public override func spec()
        {
        beforeSuite
            {
            Siesta.enabledLogCategories = LogCategory.all
            Siesta.logger = { currentLogMessages.append($1) }
            }

        beforeEach
            {
            currentTestFailed = false
            currentLogMessages.removeAll(keepCapacity: true)
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

    public override func recordFailureWithDescription(description: String, inFile filePath: String, atLine lineNumber: UInt, expected: Bool)
        {
        currentTestFailed = true
        super.recordFailureWithDescription(description, inFile: filePath, atLine: lineNumber, expected: expected)
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

        let json = ["results": results.toJson["children"] as! NSArray]
        let jsonData = try! NSJSONSerialization.dataWithJSONObject(json, options: [])
        if !jsonData.writeToFile("/tmp/siesta-spec-results.json", atomically: true)
            { print("unable to write spec results json") }

        resultsDirty = false
        }

    func recordResult(spec: QuickSpec, example: Example, passed: Bool)
        {
        recordResult(
            [specDescription(spec)] + example.name.componentsSeparatedByString(", "),
            subtree: results,
            callsite: example.callsite,
            passed: passed)
        resultsDirty = true
        }

    private func recordResult(path: [String], subtree: Result, callsite: Quick.Callsite, passed: Bool)
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

    private func specDescription(spec: QuickSpec) -> String
        {
        return spec.dynamicType.description()
            .replacingRegex("^[A-Za-z]+Tests\\.", "")
            .replacingRegex("\\.Type$", "")
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

    func child(named: String) -> Result
        {
        for child in children
            where child.name == named
                { return child }
        let newChild = Result(name: named)
        children.append(newChild)
        return newChild
        }

    var toJson: NSDictionary
        {
        var json: [String:AnyObject] = ["name": name]
        if let callsite = callsite
            {
            json["file"] = callsite.file
            json["line"] = callsite.line
            }
        if let passed = passed
            { json["passed"] = passed }
        if !children.isEmpty
            { json["children"] = children.map { $0.toJson } as NSArray }
        return json
        }
    }
