// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "LuloClippy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "lulo-clippy", targets: ["LuloClippy"]),
        .executable(name: "ambient-context-demo", targets: ["AmbientContextDemo"]),
        .library(name: "AmbientContext", targets: ["AmbientContext"])
    ],
    targets: [
        .executableTarget(
            name: "LuloClippy",
            dependencies: ["AmbientContext"],
            path: "Sources/LuloClippy",
            resources: [
                .process("../../Resources/Sprites"),
                .process("../../Resources/AppIcon")
            ]
        ),
        .target(name: "AmbientContext", path: "Sources/AmbientContext"),
        .executableTarget(
            name: "AmbientContextDemo",
            dependencies: ["AmbientContext"],
            path: "Sources/AmbientContextDemo"
        ),
        .testTarget(
            name: "LuloClippyTests",
            dependencies: ["LuloClippy"],
            path: "Tests/LuloClippyTests"
        )
    ]
)
