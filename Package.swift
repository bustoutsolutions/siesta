import PackageDescription

let package = Package(
    name: "Siesta",
    exclude: [
        "Source/SiestaUI", // One day, SwiftPM will support UIKit. Until then...
        "Tests"            // SwiftPM support for test-only dependencies like Quick is broken / nonexistent
    ]
)
