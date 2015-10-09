//
//  Siesta+SwiftyJSON.swift
//  GithubBrowser
//
//  Created by Paul on 2015/8/31.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Siesta
import SwiftyJSON

extension TypedContentAccessors {
    /**
      Adds a `.json` convenience property to resources that returns a SwiftyJSON `JSON` wrapper.
      If there is no data, then the property returns `JSON([:])`.
      
      Note that by default, Siesta parses data based on content type. This accessor is only a way
      of conveniently donwcasting and defaulting the data that Siesta has already parsed. (Parsing
      happens off the main thread in a GCD queue, never in response one of these content accessors.)
      To produce a custom data type that Siesta doesn’t already know how to parse as a Siesta
      resource’s content, you’ll need to add a custom `ResponseTransformer`.
    */
    var json: JSON {
        return JSON(contentAsType(ifNone: [:] as AnyObject))
    }
}
