// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EyesHealth",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "EyesHealth",
            path: "EyesHealth",
            exclude: ["Resources/Info.plist"]
        )
    ]
)
