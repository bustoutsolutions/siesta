//
//  Stubs.swift
//  SiestaExampleTest
//
//  Created by Paul on 2016/11/2.
//  Copyright © 2016 Kodama Software. All rights reserved.
//

import Foundation
import Siesta

struct JSON {
    var arrayValue: [JSON] = []
    var string: String? = ""
    
    init(_ value: Any) { }
    
    subscript (index: String) -> JSON {
        return self
    }
}

struct User {
    init(json: JSON) { }
}

struct UserProfile {
    init(json: JSON) { }
}

struct Item {
    init(json: JSON) { }
}

struct Repository {
    init(json: JSON) { }
}

class MyAPI {
    static var authentication: Resource {
        fatalError()
    }

    static var profile: Resource {
        fatalError()
    }
    
    var authToken: String?
}

class MyObserver: ResourceObserver {
    func resourceChanged(_ resource: Resource, event: ResourceEvent) { }
}

class DummyObject { }

let SwiftyJSONTransformer =
    ResponseContentTransformer
        { JSON($0.content as AnyObject) }

struct GithubErrorMessageExtractor: ResponseTransformer {
    func process(_ response: Response) -> Response {
        return response
    }
}
