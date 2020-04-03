//
//  RemoteImageViewSpec.swift
//  Siesta
//
//  Created by Paul on 2018/6/22.
//  Copyright © 2018 Bust Out Solutions. All rights reserved.
//

#if os(iOS) || os(tvOS)

import Foundation

import SiestaUI
import Quick
import Nimble

class RemoteImageViewSpec: SiestaSpec
    {
    override func spec()
        {
        let remoteImageView = specVar { RemoteImageView() }

        it("handles a nil imageResource")
            {
            remoteImageView().imageResource = nil
            expect(remoteImageView().imageURL).to(beNil())
            expect(remoteImageView().imageResource).to(beNil())
            }

        it("handles a nil imageURL")
            {
            remoteImageView().imageURL = nil
            expect(remoteImageView().imageURL).to(beNil())
            expect(remoteImageView().imageResource).to(beNil())
            }

        // TODO: build out SiestaUI tests
        }
    }

#endif
