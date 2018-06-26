import Siesta

func api_Structs_Pipeline<T: EntityCache>(service: Service, resource: Resource, myRealmCache: T) {


    //══════ api_Structs_Pipeline:0 ══════
    service.configure {
      $0.pipeline[.parsing].add(SwiftyJSONTransformer, contentTypes: ["*​/json"])
      $0.pipeline[.cleanup].add(GithubErrorMessageExtractor())
      $0.pipeline[.model].cacheUsing(myRealmCache)
    }

    service.configureTransformer("/item/​*") {  // Replaces .model stage by default
      Item(json: $0.content)
    }
    //════════════════════════════════════

    //══════ api_Structs_Pipeline:1 ══════
    service.configure("/secret") {
      $0.pipeline.removeAllCaches()
    }
    //════════════════════════════════════

}
