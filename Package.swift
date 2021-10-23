// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Siesta",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_12),
        .tvOS(.v9),
    ],
    products: [
        .library(name: "Siesta", targets: ["Siesta"]),
        .library(name: "SiestaUI", targets: ["SiestaUI"]),
        .library(name: "Siesta_Alamofire", targets: ["Siesta_Alamofire"]),
    ],
    dependencies: [
        // Siesta has no required third-party dependencies for use in downstream projects.

        // For optional Siesta-Alamofire module:
        .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "5.0.5")),

        // For tests:
        .package(url: "https://github.com/pcantrell/Quick", .branch("siesta")), 
        .package(url: "https://github.com/Quick/Nimble", from: "9.0.0"),
    ],
    targets: [
        .target(
            name: "Siesta"
        ),
        .target(
            name: "SiestaUI",
            dependencies: ["Siesta"],
            resources: [.process("ResourceStatusOverlay.xib")],
            swiftSettings: [
                .define("SIESTA_USE_MODULE_BUNDLE"),
            ]
        ),
        .target(
            name: "Siesta_Alamofire",
            dependencies: ["Siesta", "Alamofire"],
            path: "Extensions/Alamofire"
        ),
        .testTarget(
            name: "SiestaTests",
            dependencies: ["SiestaUI", "Siesta_Alamofire", "Quick", "Nimble"],
            path: "Tests/Functional",
            exclude: ["ObjcCompatibilitySpec.m"]  // SwiftPM currently only supports Swift
        ),
    ],
    swiftLanguageVersions: [.v5]
)
