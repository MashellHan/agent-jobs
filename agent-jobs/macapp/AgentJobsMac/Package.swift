// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentJobsMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AgentJobsMacApp", targets: ["AgentJobsMacApp"]),
        .executable(name: "capture-all", targets: ["CaptureAll"]),
        .library(name: "AgentJobsCore", targets: ["AgentJobsCore"]),
        .library(name: "AgentJobsMacUI", targets: ["AgentJobsMacUI"]),
        .library(name: "AgentJobsVisualHarness", targets: ["AgentJobsVisualHarness"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0"),
    ],
    targets: [
        .target(
            name: "AgentJobsCore",
            path: "Sources/AgentJobsCore"
        ),
        .target(
            name: "AgentJobsMacUI",
            dependencies: ["AgentJobsCore"],
            path: "Sources/AgentJobsMacUI"
        ),
        .target(
            name: "AgentJobsVisualHarness",
            dependencies: ["AgentJobsCore", "AgentJobsMacUI"],
            path: "Sources/AgentJobsVisualHarness"
        ),
        .executableTarget(
            name: "AgentJobsMacApp",
            dependencies: ["AgentJobsCore", "AgentJobsMacUI"],
            path: "Sources/AgentJobsMacApp"
        ),
        .executableTarget(
            name: "CaptureAll",
            dependencies: ["AgentJobsCore", "AgentJobsMacUI", "AgentJobsVisualHarness"],
            path: "Sources/CaptureAll"
        ),
        .testTarget(
            name: "AgentJobsCoreTests",
            dependencies: [
                "AgentJobsCore",
                "AgentJobsMacUI",
                "AgentJobsVisualHarness",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/AgentJobsCoreTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
