//
//  ARC+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/7/18.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/**
  In Swift 3, “is AnyObject” always returns true due to implicit value wrapping.
  This tests whether the argument is really a subtype of AnyObject, restoring the
  behavior of “is AnyObject” in Swift 2.
*/
internal func isObject(_ val: Any) -> Bool
    {
    return type(of: val) is AnyObject.Type
    }

/**
  A reference that can switched between behaving as a strong or a weak ref to an object,
  and can also hold a non-object type.

  - If the value is an object (i.e. T is a subtype of AnyObject), then...
    - ...if strong == true, then StrongOrWeakRef holds a strong reference to value.
    - ...if strong == false, then StrongOrWeakRef holds a weak reference to value.
  - If the value is not an object (e.g. a struct), then...
    - ...if strong == true, then StrongOrWeakRef holds the structure.
    - ...if strong == false, then StrongOrWeakRef immediately discards the structure.
*/
internal struct StrongOrWeakRef<T>
    {
    private var strongRef: T?
    private weak var weakRef: AnyObject?
    var value: T?
        { return strongRef ?? (weakRef as? T) }

    init(_ value: T)
        {
        strongRef = value
        weakRef = value as AnyObject
        // More performant version of previous line, once
        // https://bugs.swift.org/browse/SR-2867 is fixed:
//        weakRef = isObject(value)
//            ? value as AnyObject?
//            : nil
        }

    var strong: Bool
        {
        get { return strongRef != nil }
        set { strongRef = newValue ? value : nil }
        }
    }

/**
  A weak ref suitable for use in collections. This struct maintains stable behavior for == and hashValue even
  after the referenced object has been deallocated, making it suitable for use as a Set member and a Dictionary key.
*/
internal struct WeakRef<T: AnyObject>: Hashable
    {
    private(set) weak var value: T?
    private let originalIdentity: UInt
    private let originalHash: Int

    init(_ value: T)
        {
        self.value = value
        let ident = ObjectIdentifier(value)
        self.originalIdentity = UInt(bitPattern: ident)
        self.originalHash = ident.hashValue
        }

    var hashValue: Int
        { return originalHash }

    internal static func == <T>(lhs: WeakRef<T>, rhs: WeakRef<T>) -> Bool
        {
        return lhs.originalIdentity == rhs.originalIdentity
        }
    }
