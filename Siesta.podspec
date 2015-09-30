Pod::Spec.new do |s|

  s.name         = "Siesta"
  s.version      = "1.0-beta.1"
  s.summary      = "iOS REST Client Framework"

  s.description  = <<-DESC
                   Drastically simplifies app code by providing a client-side cache of observable models for RESTful resources.

                   Siesta ends the stateful headache of client-side network request management by providing an observable model of a RESTful resource’s state. The model answers three basic questions:

                   * What is the latest data for this resource, if any?
                   * Did the latest request result in an error?
                   * Is there a request in progress?

                   …then provides notifications whenever the answers to these questions change.

                   Siesta handles all the transitions and corner cases to deliver these answers wrapped up with a pretty bow on top, letting you focus on your UI.

                   ## Requirements

                   * **OS:** iOS 8+
                   * **Languages:** Written in Swift, supports Swift and Objective-C
                   * **Build requirements:** Xcode 7 beta 6, Swift 2.0
                   * **License:** MIT
                   * **Status:** 1.0 release now in beta. Seeking feedback. Please experiment!

                   ## Features

                   - Decouples UI component lifecycles from network request lifecycles
                   - Eliminates error-prone state tracking logic
                   - Eliminates redundant network requests
                   - Unified reporting for all errors: encoding, network, server-side, and parsing
                   - Transparent Etag / If-Modified-Since handling
                   - Painless handling for JSON and plain text, plus customizable response transformation
                   - Prebaked UI for loading & error handling
                   - Debug-friendly, customizable logging
                   - Written in Swift with a great [Swift-centric API](https://bustoutsolutions.github.io/siesta/api/), but…
                   - …also works great from Objective-C thanks to a compatibility layer.
                   - Lightweight. Won’t achieve sentience and attempt to destroy you.
                   - [Robust regression tests](https://bustoutsolutions.github.io/siesta/specs/)
                   - [Documentation](https://bustoutsolutions.github.io/siesta/guide/)

                   DESC

  s.homepage     = "http://bustoutsolutions.github.io/siesta/"
  s.license      = "MIT"

  s.authors = { "Bust Out Solutions, Inc." => "hello@bustoutsolutions.com", "Paul Cantrell" => "https://innig.net" }
  s.social_media_url = "https://twitter.com/teambustout"

  s.documentation_url = "https://bustoutsolutions.github.io/siesta/guide/"

  s.ios.deployment_target = "8.0"

  s.source       = { :git => "https://github.com/bustoutsolutions/siesta.git", :tag => "1.0-beta.1" }
  s.resources = "Source/**/*.xib"

  s.subspec "Core" do |s|
    s.source_files = "Source/**/*"
    s.exclude_files = "Source/Networking-Alamofire.swift"
  end

  s.subspec "Alamofire" do |s|
    s.source_files = "Source/Networking-Alamofire.swift"
    s.dependency "Siesta/Core"
    s.dependency "Alamofire", "2.0.2"
  end

  s.default_subspecs = 'Core'

end
