// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentJobsMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AgentJobsMac", targets: ["AgentJobsMac"]),
        .library(name: "AgentJobsCore", targets: ["AgentJobsCore"]),
    ],
    targets: [
        .executableTarget(
            name: "AgentJobsMac",
            dependencies: ["AgentJobsCore"],
            path: "Sources/AgentJobsMac"
        ),
        .target(
            name: "AgentJobsCore",
            path: "Sources/AgentJobsCore"
        ),
        .testTarget(
            name: "AgentJobsCoreTests",
            dependencies: ["AgentJobsCore"],
            path: "Tests/AgentJobsCoreTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
