import Siesta

func guide_requests(service: Service, resource: Resource) {
    let newState = ["foo": "bar"]
    let rawData = Data()
                                                                                                        
    //══════ guide_requests:0 ══════
    MyAPI.profile.loadIfNeeded()
    //════════════════════════════════════
        
    //══════ guide_requests:1 ══════
    MyAPI.profile.load()
    //════════════════════════════════════
        
    //══════ guide_requests:2 ══════
    MyAPI.profile.invalidate()
    //════════════════════════════════════
        
    //══════ guide_requests:3 ══════
    // MyAPI.profile.request → _ = MyAPI.profile.request
    _ = MyAPI.profile.request(.post, json: ["foo": [1,2,3]])
    _ = MyAPI.profile.request(.post, urlEncoded: ["foo": "bar"])
    _ = MyAPI.profile.request(.post, text: "Many years later, in front of the terminal...")
    _ = MyAPI.profile.request(.post, data: rawData, contentType: "text/limerick")
    //════════════════════════════════════
        
    //══════ guide_requests:4 ══════
    resource.load()
        .onSuccess { data in print("Wow! Data!") }
        .onFailure { error in print("Oh, bummer.") }
    //════════════════════════════════════
        
    //══════ guide_requests:5 ══════
    resource.request(.put, json: newState).onSuccess() {
        _ in resource.load()
    }
    //════════════════════════════════════
        
    //══════ guide_requests:6 ══════
    // … → print(createdResource)
    resource.request(.post, json: newState).onSuccess() {
        let createdResource = resource.optionalRelative(
            $0.header(forKey: "Location"))
        print(createdResource)
    }
    //════════════════════════════════════
        
    //══════ guide_requests:7 ══════
    resource.request(.put, json: newState).onSuccess() {
        _ in resource.overrideLocalContent(with: newState)
    }
    //════════════════════════════════════
        
    //══════ guide_requests:8 ══════
    resource.request(.patch, json: ["foo": "bar"]).onSuccess() { _ in
        var updatedState = resource.jsonDict
        updatedState["foo"] = "bar"
        resource.overrideLocalContent(with: updatedState)
    }
    //════════════════════════════════════
    
    _ =                                                                                            
    //══════ guide_requests:9 ══════
    // … → _ in
    resource.load(using:
        resource.request(.put, json: newState)
            .onSuccess() { _ in })
    //════════════════════════════════════
    
}
