//
//  OpenEnum.swift
//  Siesta
//
//  Created by Paul on 2016/6/3.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

//  A protocol for enum-like types that allow third-party modules to add values.
/// :nodoc:
public protocol _OpenEnum: AnyObject, Hashable
    {
    }

extension _OpenEnum
    {
    /// :nodoc:
    public static func == (lhs: Self, rhs: Self) -> Bool
        { return lhs === rhs }

    /// :nodoc:
    public func hash(into hasher: inout Hasher)
        { hasher.combine(ObjectIdentifier(self)) }
    }
