// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "Fallback",
    products: [
        .library(
            name: "Fallback",
            targets: ["Fallback"]
        ),
    ],
    targets: [
        .target(name: "Fallback", path: "Sources"),
        .testTarget(
            name: "FallbackTests",
            dependencies: ["Fallback"],
            path: "Tests"
        ),
    ]
)
