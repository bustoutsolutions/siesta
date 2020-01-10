// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Siesta",
    products: [
        .library(name: "Siesta", targets: ["Siesta"]),
        .library(name: "SiestaUI", targets: ["SiestaUI"])
    ],
    targets: [
        .target(name: "Siesta"),
        .target(
            name: "SiestaUI",
            dependencies: ["Siesta"]
        )
    ]
)
