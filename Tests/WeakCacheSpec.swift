//
//  WeakCacheSpec.swift
//  Siesta
//
//  Created by Paul on 2015/6/27.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

@testable import Siesta
import Quick
import Nimble

class WeakCacheSpec: SiestaSpec
    {
    override func spec()
        {
        super.spec()

        let cache = specVar { WeakCache<String,Doodad>() }

        describe("get()")
            {
            let doodad0 = specVar { Doodad() }
            let doodad1 = specVar { Doodad() }
            let doodad2 = specVar { Doodad() }

            it("returns a newly created instance")
                {
                let retrieved = cache().get("foo") { return doodad0() }
                expect(retrieved) === doodad0()
                }

            it("returns the same instance on the second fetch")
                {
                cache().get("foo") { return doodad0() }
                let retrieved = cache().get("foo") { return doodad1() }
                expect(retrieved) === doodad0()
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
                expect(retrieved0) === doodad0()
                expect(retrieved1) === doodad1()
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
                expect(Doodad.count) == 0

                let newDoodad = Doodad()
                let secondFetch = cache().get("foo") { return newDoodad }
                expect(secondFetch) === newDoodad
                }

            it("holds on to retained instances")
                {
                cache().flushUnused()
                expect(Doodad.count) == 1

                let newDoodad = Doodad()
                let secondFetch = cache().get("foo") { return newDoodad }
                expect(secondFetch) === expendable
                }

            it("responds to low memory events")
                {
                expendable = nil
                simulateMemoryWarning()
                expect(Doodad.count) == 0
                }
            }

        describe("entryCountLimit")
            {
            var entryID = 0

            func makeEntries(count: Int)
                {
                for _ in 0 ..< count
                    {
                    entryID += 1
                    cache().get("Entry \(entryID)")
                        { return Doodad() }
                    }
                }

            beforeEach
                { cache().countLimit = 100 }

            it("flushes unused entried when exceeded")
                {
                makeEntries(100)
                expect(Doodad.count) == 100
                makeEntries(1)
                expect(Doodad.count) == 1
                }

            it("does not flush entries still in use")
                {
                let retainedDoodad = Doodad()
                cache().get("sticky")
                    { return retainedDoodad }

                makeEntries(101)

                expect(Doodad.count) == 3  // 1 sticky + 2 after total hit 100
                let refetched = cache().get("sticky") { return Doodad() }
                expect(refetched) === retainedDoodad
                }

            it("flushes entries if lowered below current count")
                {
                makeEntries(90)
                cache().countLimit = 80
                expect(Doodad.count) == 0
                }
            }
        }
    }

private class Doodad
    {
    static var count: Int = 0

    init() { Doodad.count += 1 }
    deinit { Doodad.count -= 1 }
    }
