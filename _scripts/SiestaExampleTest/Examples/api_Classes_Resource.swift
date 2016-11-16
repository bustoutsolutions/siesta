import Siesta

func api_Classes_Resource(service: Service, resource: Resource) {

                                                                                                                                                                                                                            
    //══════ api_Classes_Resource:1 ══════
    // ... → _ in
    resource.request(.get)
        .onSuccess { _ in }
        .onFailure { _ in }
    //════════════════════════════════════
    
    let imageData = Data()
    _ =                                                                                                        
    //══════ api_Classes_Resource:0 ══════
    resource.request(.post) {
      $0.httpBody = imageData
      $0.addValue("image/png", forHTTPHeaderField: "Content-Type")
    }
    //════════════════════════════════════
        
    //══════ api_Classes_Resource:3 ══════
    resource.request(.post, json: ["name": "Fred"])
      .onSuccess { _ in resource.load() }
    //════════════════════════════════════
    
    let user = "user"
    let pass = "foo"                                                                                                                                                                    
    //══════ api_Classes_Resource:2 ══════
    let auth = MyAPI.authentication
    auth.load(using:
      auth.request(
          .post, json: ["user": user, "password": pass]))
    //════════════════════════════════════
        
    //══════ api_Classes_Resource:4 ══════
    resource.request(.post, json: ["name": "Fred"])
      .onSuccess {
          partialEntity in
    
          // Make a mutable copy of the current content
          guard resource.latestData != nil else {
              resource.load()  // No existing entity to update, so refresh
              return
          }
    
          // Do the incremental update
          var updatedContent = resource.jsonDict
          updatedContent["name"] = partialEntity.jsonDict["newName"]
    
          // Make that the resource’s new entity
          resource.overrideLocalContent(with: updatedContent)
      }
    //════════════════════════════════════
        
    //══════ api_Classes_Resource:5 ══════
    // resource.child → _ = resource.child
    let resource = service.resource("/widgets")
    _ = resource.child("123").child("details")
      //→ /widgets/123/details
    //════════════════════════════════════
        
    //══════ api_Classes_Resource:6 ══════
    // ... → print(ownerResource)
    let href = resource.jsonDict["owner"] as? String  // href is an optional
    if let ownerResource = resource.optionalRelative(href) {
      print(ownerResource)
    }
    //════════════════════════════════════
    
}
