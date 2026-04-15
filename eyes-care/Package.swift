// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "EyesCare",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "EyesCare", targets: ["EyesCareApp"])
    ],
    targets: [
        .target(
            name: "EyesCareCore",
            path: "Sources/EyesCareCore"
        ),
        .executableTarget(
            name: "EyesCareApp",
            dependencies: ["EyesCareCore"],
            path: "Sources/EyesCareApp"
        )
    ]
)
