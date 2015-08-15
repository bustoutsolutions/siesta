//
//  TypedContent+SwiftyJSON.swift
//  GithubBrowser
//
//  Created by Paul on 2015/8/14.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import SwiftyJSON
import Siesta

extension TypedContentAccessors {
    var json:      JSON { return JSON(dictContent) }
    var jsonArray: JSON { return JSON(arrayContent) }
}
