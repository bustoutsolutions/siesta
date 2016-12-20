import Siesta

func guide_state(service: Service, resource: Resource) {

                                                                                                                                                                                                                                                        
    //══════ guide_state:0 ══════
    // resource. → _ = resource.
    // _ = resource.typedContent → let _: String? = resource.typedContent
    _ = resource.latestData?.content // Gives the content of the last successful load. This
                                 // is the fully parsed content, after it has run through
                                 // the transformer pipeline.
    
    _ = resource.latestData?.headers // Because metadata matters too
    
    _ = resource.text                // Convenience accessors return empty string/dict/array
    _ = resource.jsonDict            // if data is either (1) not present or (2) not of the
    _ = resource.jsonArray           // expected type. This reduces futzing with optionals.
    
    let _: String? = resource.typedContent()      // Convenience for casting content to arbitrary types.
                                 // Especially useful if you configured the transformer
                                 // pipeline to return models.
    //════════════════════════════════════
        
    //══════ guide_state:1 ══════
    // resource. → _ = resource.
    _ = resource.isRequesting        // True if any requests for this resource are in progress
    _ = resource.isLoading           // True if any requests in progress will update
                                 // latestData / latestError upon completion.
    //════════════════════════════════════
        
    //══════ guide_state:2 ══════
    // resource. → _ = resource.
    _ = resource.latestError               // Present if latest load attempt failed
    _ = resource.latestError?.userMessage  // String suitable for display in UI
    //════════════════════════════════════
    
}
