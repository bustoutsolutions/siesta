//
//  Siesta+SwiftyJSON.swift
//  GithubBrowser
//
//  Created by Paul on 2016/11/14.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import SwiftyJSON
import Siesta

/// Add to a reponse pipeline to wrap JSON responses with SwiftyJSON
let SwiftyJSONTransformer =
    ResponseContentTransformer(transformErrors: true)
        { JSON($0.content as AnyObject) }

/// Provides a .json convenience accessor to get raw JSON from resources
extension TypedContentAccessors {
    var json: JSON {
        return typedContent(ifNone: JSON.null)
    }
}

