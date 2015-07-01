//
//  WeakCacheSpec.swift
//  Siesta
//
//  Created by Paul on 2015/6/27.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

@testable import Siesta
import Quick
import Nimble

class WeakCacheTests: QuickSpec
    {
    override func spec()
        {
        let cache = specVar { WeakCache<String,Doodad>() }
        
        describe("get()")
            {
            let doodad0 = specVar { Doodad() }
            let doodad1 = specVar { Doodad() }
            let doodad2 = specVar { Doodad() }
            
            it("returns a newly created instance")
                {
                let retrieved = cache().get("foo") { return doodad0() }
                expect(retrieved).to(beIdenticalTo(doodad0()))
                }
            
            it("returns the same instance on the second fetch")
                {
                cache().get("foo") { return doodad0() }
                let retrieved = cache().get("foo") { return doodad1() }
                expect(retrieved).to(beIdenticalTo(doodad0()))
                }
            
            it("does not call the cache miss block on the second fetch")
                {
                cache().get("foo") { return doodad0() }
                cache().get("foo")
                    {
                    XCTFail("Block should not have been called")
                    return doodad0()
                    }
                }
            
            it("returns different instances for different keys")
                {
                cache().get("foo") { return doodad0() }
                cache().get("bar") { return doodad1() }

                let retrieved1 = cache().get("bar") { return doodad2() }
                let retrieved0 = cache().get("foo") { return doodad2() }
                expect(retrieved0).to(beIdenticalTo(doodad0()))
                expect(retrieved1).to(beIdenticalTo(doodad1()))
                }
            }
        
        describe("flushUnused()")
            {
            var expendable: Doodad?
            
            beforeEach
                {
                Doodad.count = 0
                expendable = Doodad()
                cache().get("foo") { return expendable! }
                }
                
            afterEach
                { expendable = nil }
            
            it("discards unused instances")
                {
                expendable = nil
                cache().flushUnused()
                expect(Doodad.count).to(equal(0))
                
                let newDoodad = Doodad()
                let secondFetch = cache().get("foo") { return newDoodad }
                expect(secondFetch).to(beIdenticalTo(newDoodad))
                }
            
            it("holds on to retained instances")
                {
                cache().flushUnused()
                expect(Doodad.count).to(equal(1))
                
                let newDoodad = Doodad()
                let secondFetch = cache().get("foo") { return newDoodad }
                expect(secondFetch).to(beIdenticalTo(expendable))
                }
            
            it("responds to low memory events")
                {
                expendable = nil
                simulateMemoryWarning()
                expect(Doodad.count).to(equal(0))
                }
            }
        }
    }

private class Doodad
    {
    static var count: Int = 0
    
    init() { Doodad.count++ }
    deinit { Doodad.count-- }
    }
