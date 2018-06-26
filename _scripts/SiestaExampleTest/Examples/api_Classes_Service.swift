import Siesta

func api_Classes_Service(service: Service, resource: Resource) {

    //══════ api_Classes_Service:0 ══════
    // service. → _ = service.
    _ = service.resource("users")   // same
    _ = service.resource("/users")  // thing
    //════════════════════════════════════

    //══════ api_Classes_Service:4 ══════
    service.configureTransformer("**") {
      $0.content as JSONConvertible  // error if content from upstream in pipeline is not JSONConvertible
    }
    //════════════════════════════════════

    let profileResource = resource

    //══════ api_Classes_Service:6 ══════
    service.wipeResources(matching: "/secure/​**")
    service.wipeResources(matching: profileResource)
    //════════════════════════════════════

    //══════ api_Classes_Service:7 ══════
    service.wipeResources(matching: "/secure/​**")
    service.wipeResources(matching: profileResource)
    //════════════════════════════════════
}

class Foo: Service {

    struct FooModel {
        init(json: JSON) { }
    }

    //══════ api_Classes_Service:5 ══════
    var flavor: String? {
      didSet { invalidateConfiguration() }
    }

    init() {
      super.init(baseURL: "https://api.github.com")
      configure {
        $0.headers["Flavor-of-the-month"] = self.flavor  // NB: use weak self if service isn’t a singleton
      }
    }
    //════════════════════════════════════

    func configurationExamples<T: EntityCache>(userProfileCache: T) {

        let token = "token"

        //══════ api_Classes_Service:1 ══════
        configure { $0.expirationTime = 10 }  // global default

        configure("/items")    { $0.expirationTime = 5 }
        configure("/items/​*")  { $0.headers["Funkiness"] = "Very" }
        configure("/admin/​**") { $0.headers["Auth-token"] = token }

        let user = resource("/user/current")
        configure(user) {
          $0.pipeline[.model].cacheUsing(userProfileCache)
        }
        //════════════════════════════════════

        //══════ api_Classes_Service:2 ══════
        configureTransformer("/foo/​*") {
          FooModel(json: $0.content)
        }
        //════════════════════════════════════

        //══════ api_Classes_Service:3 ══════
        configureTransformer("/foo/​*", requestMethods: [.get]) {
          FooModel(json: $0.content)
        }

        configureTransformer("/foo/​*", requestMethods: [.post, .put, .patch]) {
          UpdateResult<FooModel>(json: $0.content)
        }
        //════════════════════════════════════

    }
}

struct UpdateResult<T> {
    init(json: Any) { }
}

