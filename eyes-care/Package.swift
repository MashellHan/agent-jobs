// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EyesCare",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "EyesCare", targets: ["EyesCareApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.12.0")
    ],
    targets: [
        .target(
            name: "EyesCareCore",
            path: "Sources/EyesCareCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "EyesCareApp",
            dependencies: ["EyesCareCore"],
            path: "Sources/EyesCareApp",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "EyesCareTests",
            dependencies: [
                "EyesCareCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/EyesCareTests",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
