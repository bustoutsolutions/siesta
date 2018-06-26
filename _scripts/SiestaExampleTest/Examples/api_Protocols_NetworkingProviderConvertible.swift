import Siesta

func api_Protocols_NetworkingProviderConvertible(service: Service, resource: Resource) {

    _ =
    //══════ api_Protocols_NetworkingProviderConvertible:0 ══════
    Service(baseURL: "http://foo.bar", networking:
      URLSessionProvider(session:
          URLSession(configuration:
              URLSessionConfiguration.default)))
    //════════════════════════════════════

    _ =
    //══════ api_Protocols_NetworkingProviderConvertible:1 ══════
    Service(baseURL: "http://foo.bar", networking:
      URLSessionConfiguration.default)
    //════════════════════════════════════

}
