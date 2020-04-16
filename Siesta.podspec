Pod::Spec.new do |s|

  s.name         = "Siesta"
  s.version      = "1.5.1"
  s.summary      = "Swift REST client library"

  s.description  = <<-DESC
                   An elegant abstraction for REST APIs that untangles stateful messes and drastically simplifies app code. A **resource-centric** alternative to the familiar **request-centric** approach.

                   Siesta ends the stateful headache of client-side network request management by providing an observable model of a RESTful resource’s state. The model answers three basic questions:

                   * What is the latest data for this resource, if any?
                   * Did the latest request result in an error?
                   * Is there a request in progress?

                   …then provides notifications whenever the answers to these questions change.

                   Siesta handles all the transitions and corner cases to deliver these answers wrapped up with a pretty bow on top, letting you focus on your logic and UI.

                   ## Stats

                   * **OS:** iOS 10+, macOS 10.11+, tvOS 9.0+
                   * **Languages:** Written in Swift, supports apps in both Swift and Objective-C
                   * **Tool requirements:** Xcode 11.3+, Swift 5.1+
                   * **License:** MIT

                   ## Features

                   - Decouples view, model, and controller lifecycle from network request lifecycle
                   - Decouples request initiation from request configuration
                   - Eliminates error-prone state tracking logic
                   - Eliminates redundant network requests
                   - Unified handling for all errors: encoding, network, server-side, and parsing
                   - Highly extensible, multithreaded response deserialization
                   - Transparent built-in parsing (which you can turn off) for JSON, text, and images
                   - Smooth progress reporting that accounts for upload, download, _and_ latency
                   - Transparent Etag / If-Modified-Since handling
                   - Prebaked UI helpers for loading & error handling, remote images
                   - Debug-friendly, customizable logging
                   - Written in Swift with a great [Swift-centric API](https://bustoutsolutions.github.io/siesta/api/), but…
                   - …also works great from Objective-C thanks to a compatibility layer.
                   - Lightweight. Won’t achieve sentience and attempt to destroy you.
                   - [Robust regression tests](https://bustoutsolutions.github.io/siesta/specs/)
                   - [Documentation](https://bustoutsolutions.github.io/siesta/guide/) and [more documentation](https://bustoutsolutions.github.io/siesta/api/)

                   ## What it doesn’t do

                   - It **doesn’t reinvent networking.** Siesta delegates network operations to your library of choice (`URLSession` by default, or [Alamofire](https://github.com/Alamofire/Alamofire), or inject your own [custom adapter](http://bustoutsolutions.github.io/siesta/api/Protocols/NetworkingProvider.html)).
                   - It **doesn’t hide HTTP**. On the contrary, Siesta strives to expose the full richness of HTTP while providing conveniences to simplify common usage patterns. You can devise an abstraction layer to suit your own particular needs, or work directly with Siesta’s nice APIs for requests and response entities.
                   - It **doesn’t do automatic response ↔ model mapping.** This means that Siesta doesn’t constrain your response models, or force you to have any at all. Add a response transformer to output models of whatever flavor your app prefers, or work directly with parsed JSON.

                   ## Documentation

                   - **[Full README](https://github.com/bustoutsolutions/siesta)**
                   - **[User Guide](https://bustoutsolutions.github.io/siesta/guide/)**
                   - **[API documentation](https://bustoutsolutions.github.io/siesta/api/)**
                   - **[Specs](https://bustoutsolutions.github.io/siesta/specs/)**

                   DESC

  s.homepage     = "http://bustoutsolutions.github.io/siesta/"
  s.license      = "MIT"

  s.authors = { "Bust Out Solutions, Inc." => "hello@bustoutsolutions.com", "Paul Cantrell" => "https://innig.net" }
  s.social_media_url = "https://twitter.com/siestaframework"

  s.documentation_url = "https://bustoutsolutions.github.io/siesta/"

  s.swift_version = "5.0"

  s.ios.deployment_target = "10.0"
  s.osx.deployment_target = "10.12"
  s.tvos.deployment_target = "10.0"

  s.source = { :git => "https://github.com/bustoutsolutions/siesta.git", :tag => "1.5.1" }

  s.subspec "Core" do |s|
    s.source_files = "Source/Siesta/**/*"
    s.exclude_files = "**/Info*.plist"
  end

  s.subspec "UI" do |s|
    s.ios.source_files = "Source/SiestaUI/**/*.{swift,m,h}"
    s.dependency "Siesta/Core"
    s.exclude_files = "**/Info*.plist"
    s.ios.resources = "Source/**/*.xib"
  end

  s.subspec "Alamofire" do |s|
    s.source_files = "Extensions/Alamofire/**/*.{swift,m,h}"
    s.dependency "Siesta/Core"
    s.dependency "Alamofire", "> 5.0"
  end

  s.default_subspecs = 'Core'

end
