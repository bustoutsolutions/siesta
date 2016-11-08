import Siesta

func api_Structs_PipelineStage(service: Service, resource: Resource) {

    /*                                                                                            
    //══════ api_Structs_PipelineStage:0 ══════
    "text/plain"
    "text/​*"
    "application/​*+json"
    //════════════════════════════════════
    
    */
                                                                                                    
    //══════ api_Structs_PipelineStage:1 ══════
    service.configure("/thinger/​*.raw") {
      $0.pipeline[.parsing].removeTransformers()
    }
    //════════════════════════════════════
    
}
