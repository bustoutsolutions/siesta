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
    */
    var json: JSON {
        return JSON(contentAsType(ifNone: [:] as AnyObject))
    }
}
