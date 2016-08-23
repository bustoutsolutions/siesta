import PackageDescription

let package = Package(
    name: "Siesta",

    // testDependencies apparently doesn't work, and the projects we depend on
    // don't seem to be SwiftPM-ready anyhow.

    // One day, SwiftPM will support UIKit. Until then...
    exclude: ["Source/SiestaUI"]
)
