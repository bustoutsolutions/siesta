// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Siesta",
    platforms: [
        .iOS(.v8),
        .macOS(.v10_11),
        .tvOS(.v9),
    ],
    products: [
        .library(name: "Siesta", targets: ["Siesta"]),
        .library(name: "SiestaUI", targets: ["SiestaUI"]),
    ],
    dependencies: [
        // .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "5.0.5")),
        .package(url: "https://github.com/pcantrell/Quick", .branch("around-each")), 
        .package(url: "https://github.com/Quick/Nimble", from: "8.0.1"),
    ],
    targets: [
        .target(
            name: "Siesta"
        ),
        .target(
            name: "SiestaUI",
            dependencies: ["Siesta"]
        ),
        .testTarget(
            name: "SiestaTests",
            dependencies: ["SiestaUI", "Quick", "Nimble"],
            path: "Tests/Functional",
            exclude: ["ObjcCompatibilitySpec.m"]  // SwiftPM currently only supports Swift
        ),
    ],
    swiftLanguageVersions: [.v5]
)
