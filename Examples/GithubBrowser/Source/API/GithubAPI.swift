//
//  GithubAPI.swift
//  GithubBrowser
//
//  Created by Paul on 2015/7/7.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Siesta

class _GithubAPI: Service {

    private init() {
        super.init(base: "https://api.github.com")
        
        #if DEBUG
            Siesta.enabledLogCategories = LogCategory.common
        #endif
    }
    
    // Resource convenience accessors
    
    func user(username: String) -> Resource {
        return resource("users").child(username)
    }
}

let GithubAPI = _GithubAPI()

