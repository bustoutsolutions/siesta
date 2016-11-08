import Siesta

func api_Protocols_ResourceObserver(service: Service, resource: Resource) {

                                                                                                                                                                                                                
    //══════ api_Protocols_ResourceObserver:0 ══════
    var myObserver: MyObserver? = MyObserver()
    resource.addObserver(myObserver!)  // myObserver is self-owned, so...
    myObserver = nil                   // this deallocates it, but...
    // ...myObserver never receives stoppedObserving(resource:).
    //════════════════════════════════════
    
}
