//
//  ResourceBacked.swift
//  Siesta
//
//  Created by Paul on 2020/3/31.
//  Copyright © 2020 Bust Out Solutions. All rights reserved.
//

import Foundation

@propertyWrapper
public class ResourceBacked<ContentType>: AnyResourceBacked
    {
    public var defaultData: ContentType
    public var loadAutomatically: Bool

    private var observers = [ResourceObserver]()

    public var resource: Resource?
        {
        willSet
            {
            resource?.removeObservers(ownedBy: self)
            }

        didSet
            {
            resource?.addObserver(owner: self)
                {
                [weak self] _,_ in
                if let self = self
                    { self.wrappedValue = self.resource?.typedContent() ?? self.defaultData }
                }

            for observer in observers
                { resource?.addObserver(observer, owner: self) }

            if loadAutomatically
                { resource?.loadIfNeeded() }
            }
        }

    public init(default defaultData: ContentType, loadAutomatically: Bool = true)
        {
        self.wrappedValue = defaultData
        self.defaultData = defaultData
        self.loadAutomatically = loadAutomatically
        }

    public private(set) var wrappedValue: ContentType

    public var projectedValue: ResourceBacked
        { self }

    @discardableResult
    public func addObserver(_ observer: ResourceObserver) -> Self
        {
        observers.append(observer)
        resource?.addObserver(observer, owner: self)
        return self
        }

    @discardableResult
    public func addObserver(
            file: String = #file,
            line: Int = #line,
            closure: @escaping ResourceObserverClosure)
        -> Self
        {
        addObserver(
            ClosureObserver(
                closure: closure,
                debugDescription: "ClosureObserver(\(conciseSourceLocation(file: file, line: line)))"))
        }

    public var isLoading: Bool
        { resource?.isLoading ?? false }
    }

public protocol AnyResourceBacked
    {
    var resource: Resource? { get set }

    @discardableResult
    func addObserver(_ observer: ResourceObserver) -> Self

    @discardableResult
    func addObserver(file: String, line: Int, closure: @escaping ResourceObserverClosure) -> Self

    var isLoading: Bool { get }
    }
