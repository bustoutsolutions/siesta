import Siesta

func guide_services_resources_0(service: Service, resource: Resource) {
                                                                                                                                                
    //══════ guide_services_resources:0 ══════
    let myAPI = Service(baseURL: "https://api.example.com")  // global var
    //════════════════════════════════════
    
    print(myAPI)
}

func guide_services_resources_1(service: Service, resource: Resource) {
                                                                                                                                            
    //══════ guide_services_resources:1 ══════
    class MyAPI: Service {
      init() {
        super.init(baseURL: "https://api.example.com")
      }
    
      var profile: Resource { return resource("/profile") }
      var items:   Resource { return resource("/items") }
    
      func item(id: String) -> Resource {
        return items.child(id)
      }
    }
    
    let myAPI = MyAPI()
    //════════════════════════════════════
        
    //══════ guide_services_resources:2 ══════
    // myAPI.resource → _ = myAPI.resource
    _ = myAPI.resource("/profile")
    _ = myAPI.resource("/items/123")
    //════════════════════════════════════
        
    //══════ guide_services_resources:3 ══════
    // myAPI.resource → _ = myAPI.resource
    // The following all return the same resource:
    
    _ = myAPI.resource("/items/123/detail")
    _ = myAPI.resource("/items").child("123").child("detail")
    _ = myAPI.resource("/items").child("123/detail")
    
    _ = myAPI.resource("/items").relative("./123/detail")
    _ = myAPI.resource("/items/456").relative("./123/detail")
    _ = myAPI.resource("/items/456/detail").relative("../123/detail")
    _ = myAPI.resource("/doodads/etc").relative("/items/123/detail")
    //════════════════════════════════════
    
}
