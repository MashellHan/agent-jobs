// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentJobsMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AgentJobsMac", targets: ["AgentJobsMac"]),
        .library(name: "AgentJobsCore", targets: ["AgentJobsCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0"),
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
            dependencies: [
                "AgentJobsCore",
                "AgentJobsMac",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/AgentJobsCoreTests"
        ),
    ]
)

