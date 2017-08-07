@@ -1,23 +0,0 @@
//
//  Siesta+SwiftyJSON.swift
//  GithubBrowser
//
//  Created by Paul on 2016/11/14.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import SwiftyJSON
import Siesta

/// Add to a reponse pipeline to wrap JSON responses with SwiftyJSON.
let SwiftyJSONTransformer =
    ResponseContentTransformer(transformErrors: true)
        { JSON($0.content as AnyObject) }

/// Provides a .json convenience accessor to get already-wrapped SwiftyJSON from resources.
/// Will not work unless you also add `SwiftyJSONTransformer` to your pipeline.
extension TypedContentAccessors
    {
    var json: JSON
        { return typedContent(ifNone: JSON.null) }
    }

