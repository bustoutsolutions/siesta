import Siesta

func api_Structs_StandardTransformer(service: Service, resource: Resource) {

    struct Foo: Codable { }

    //══════ api_Structs_StandardTransformer:0 ══════
    let service = Service(
      baseURL: "https://example.com",
      standardTransformers: [.image, .text])  // no .json

    let jsonDecoder = JSONDecoder()
    service.configureTransformer("/foo") {
      try jsonDecoder.decode(Foo.self, from: $0.content)
    }
    //════════════════════════════════════

}
